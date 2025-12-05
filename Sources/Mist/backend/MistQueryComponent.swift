import Vapor
import Fluent

public protocol QueryComponent: Component
{
    func queryModel(on db: Database) async -> (any Model)?
}

public extension QueryComponent
{
    func handleQueryUpdate(app: Application) async
    {
        guard let model = await queryModel(on: app.db),
              let modelID = model.id,
              let html = await render(id: modelID, on: app.db, using: app.leaf.renderer)
        else { return await app.mist.clients.broadcast(Message.QueryDelete(component: name)) }
        
        await app.mist.clients.broadcast(Message.QueryUpdate(component: name, html: html))
    }
}

