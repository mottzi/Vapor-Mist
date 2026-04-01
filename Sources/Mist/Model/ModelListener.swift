import Vapor
import Fluent

extension Model {
    
    /// Registers the model listener used to refresh components after database changes.
    static func registerListener(with app: Application) {
        let listener = ModelListener<Self>(app: app)
        app.databases.middleware.use(listener)
    }
    
}

/// Database interceptor that forwards model events into component updates.
struct ModelListener<M: Model>: AsyncModelMiddleware {
    
    let app: Application

    func create(model: M, on db: Database, next: AnyAsyncModelResponder) async throws {
        try await next.create(model, on: db)
        Task.detached { await handle(.creation, of: model) }
    }

    func update(model: M, on db: Database, next: AnyAsyncModelResponder) async throws {
        try await next.update(model, on: db)
        Task.detached { await handle(.update, of: model) }
    }

    func delete(model: M, force: Bool, on db: any Database, next: any AnyAsyncModelResponder) async throws {
        try await next.delete(model, force: force, on: db)
        Task.detached { await handle(.deletion, of: model) }
    }
    
}

extension ModelListener
{
    enum ModelEvent { case creation, update, deletion }
    
    /// Routes a model event to all observing instance and query components.
    func handle(_ event: ModelEvent, of model: M) async {
        
        for instance in await app.mist.components.getInstanceComponents(using: M.self) {
            guard instance.shouldUpdate(for: model) else { continue }
            guard let modelID = model.id else { continue }
            
            switch event {
                case .creation: await handleCreate(for: instance, modelID: modelID)
                case .deletion: await handleDelete(for: instance, modelID: modelID)
                case .update:   await handleUpdate(for: instance, modelID: modelID)
            }
        }
        
        for fragment in await app.mist.components.getQueryComponents(using: M.self) {
            guard fragment.shouldUpdate(for: model) else { continue }
            await fragment.broadcastCurrent(app: app)
        }
    }
    
}

extension ModelListener {
    
    /// Renders and sends a newly created instance to subscribed clients.
    func handleCreate(for component: any InstanceComponent, modelID: UUID) async {
        
        for subscriber in await app.mist.clients.getSubscribers(of: component.name) {
            Task.detached {
                let state = await app.mist.clients.getState(for: subscriber.clientID, componentID: modelID.uuidString, default: component.defaultState)
                guard let html = await component.render(with: modelID, state: state, on: app.db, using: app.leaf.renderer) else { return }
                await app.mist.clients.send(Message.InstanceCreate(component: component.name, modelID: modelID, html: html), to: subscriber.clientID)
            }
        }
    }
    
    /// Renders and sends updated HTML for an existing instance to subscribed clients.
    func handleUpdate(for component: any InstanceComponent, modelID: UUID) async {
        
        for subscriber in await app.mist.clients.getSubscribers(of: component.name) {
            Task.detached {
                let state = await app.mist.clients.getState(for: subscriber.clientID, componentID: modelID.uuidString, default: component.defaultState)
                guard let html = await component.render(with: modelID, state: state, on: app.db, using: app.leaf.renderer) else { return }
                await app.mist.clients.send(Message.InstanceUpdate(component: component.name, modelID: modelID, html: html), to: subscriber.clientID)
            }
        }
    }
    
    /// Clears per-instance state and broadcasts removal of a deleted instance.
    func handleDelete(for component: any InstanceComponent, modelID: UUID) async {
        
        Task.detached {
            await app.mist.clients.clearState(for: modelID.uuidString)
            await app.mist.clients.broadcast(Message.InstanceDelete(component: component.name, modelID: modelID))
        }
    }
    
}
