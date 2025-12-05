import Vapor
import Fluent

extension Mist.Model
{
    static func registerListener(with app: Application)
    {
        let listener = Listener<Self>(app: app)
        app.databases.middleware.use(listener)
    }
}

struct Listener<M: Model>: AsyncModelMiddleware
{
    let app: Application

    func create(model: M, on db: Database, next: AnyAsyncModelResponder) async throws
    {
        try await next.create(model, on: db)
        Task.detached { await handle(event: .create, model: model) }
    }

    func update(model: M, on db: Database, next: AnyAsyncModelResponder) async throws
    {
        try await next.update(model, on: db)
        Task.detached { await handle(event: .update, model: model) }
    }

    func delete(model: M, force: Bool, on db: any Database, next: any AnyAsyncModelResponder) async throws
    {
        try await next.delete(model, force: force, on: db)
        Task.detached { await handle(event: .delete, model: model) }
    }
}

extension Listener
{
    enum ModelEvent { case create, update, delete }
    
    func handle(event: ModelEvent, model: M) async 
    {
        for component in await app.mist.components.getComponents(usingModel: M.self)
        {
            guard component.shouldUpdate(for: model) else { continue }

            if let queryComponent = component as? QueryComponent
            {
                await queryComponent.handleQueryUpdate(app: app)
            }
            else if let instanceComponent = component as? InstanceComponent
            {
                guard let modelID = model.id else { continue }

                switch event
                {
                    case .create: await instanceComponent.handleCreate(id: modelID, app: app)
                    case .update: await instanceComponent.handleUpdate(id: modelID, app: app)
                    case .delete: await instanceComponent.handleDelete(id: modelID, app: app)
                }
            }
        }
    }
}
