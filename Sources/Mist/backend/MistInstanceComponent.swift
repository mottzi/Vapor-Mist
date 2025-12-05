import Fluent
import Vapor

public protocol InstanceComponent: Component
{
    func allModels(on db: Database) async -> [any Model]?
}

extension InstanceComponent
{
    public func allModels(on db: Database) async -> [any Model]?
    {
        guard let primaryModelType = models.first else { return nil }
        return await primaryModelType.findAll(on: db)
    }
}

extension InstanceComponent
{
    public func makeContext(ofAll db: Database) async -> MultipleComponentContext
    {
        var modelContainers: [ModelContainer] = []

        guard let primaryModels = await allModels(on: db) else { return .empty }

        for primaryModel in primaryModels
        {
            guard let modelID = primaryModel.id else { continue }
            guard let modelContext = await makeContext(of: modelID, in: db) else { continue }

            modelContainers.append(modelContext.component)
        }

        guard modelContainers.isEmpty == false else { return .empty }

        return MultipleComponentContext(components: modelContainers)
    }
}

extension InstanceComponent
{
    public func handleCreate(id: UUID, app: Application) async
    {
        for subscriber in await app.mist.clients.subscribers(of: name)
        {
            Task.detached
            {
                let state = await app.mist.clients.state(for: subscriber.id, componentID: id.uuidString, default: defaultState)
                guard let html = await render(id: id, state: state, on: app.db, using: app.leaf.renderer) else { return }
                await app.mist.clients.send(Message.InstanceCreate(component: name, id: id, html: html), to: subscriber.id)
            }
        }
    }

    public func handleUpdate(id: UUID, app: Application) async
    {
        for subscriber in await app.mist.clients.subscribers(of: name)
        {
            Task.detached
            {
                let state = await app.mist.clients.state(for: subscriber.id, componentID: id.uuidString, default: defaultState)
                guard let html = await render(id: id, state: state, on: app.db, using: app.leaf.renderer) else { return }
                await app.mist.clients.send(Message.InstanceUpdate(component: name, id: id, html: html), to: subscriber.id)
            }
        }
    }

    public func handleDelete(id: UUID, app: Application) async
    {
        Task.detached
        {
            await app.mist.clients.clearState(for: id.uuidString)
            await app.mist.clients.broadcast(Message.InstanceDelete(component: name, id: id))
        }
    }
}
