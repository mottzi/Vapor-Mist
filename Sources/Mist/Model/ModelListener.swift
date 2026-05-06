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
        await handle(.creation, of: model)
    }

    func update(model: M, on db: Database, next: AnyAsyncModelResponder) async throws {
        try await next.update(model, on: db)
        await handle(.update, of: model)
    }

    func delete(model: M, force: Bool, on db: any Database, next: any AnyAsyncModelResponder) async throws {
        try await next.delete(model, force: force, on: db)
        await handle(.deletion, of: model)
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
                case .creation:
                    await app.mist.delivery.deliverInstanceMutation(
                        .create,
                        of: instance,
                        modelID: modelID
                    )

                case .deletion:
                    await app.mist.delivery.deliverInstanceDeletion(
                        of: instance,
                        modelID: modelID
                    )

                case .update:
                    await app.mist.delivery.deliverInstanceMutation(
                        .update,
                        of: instance,
                        modelID: modelID
                    )
            }
        }
        
        for fragment in await app.mist.components.getQueryComponents(using: M.self) {
            guard fragment.shouldUpdate(for: model) else { continue }
            await app.mist.delivery.broadcastCurrentFragment(fragment)
        }
    }
    
}
