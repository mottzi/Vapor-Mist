import Vapor
import Fluent

extension Mist.Model {
    
    static func registerListener(with app: Application) {
        let listener = Listener<Self>(app: app)
        app.databases.middleware.use(listener)
    }
    
}

struct Listener<M: Model>: AsyncModelMiddleware {
    
    let app: Application
    
    func update(model: M, on db: Database, next: AnyAsyncModelResponder) async throws {
        
        try await next.update(model, on: db)
        
        guard let modelID = model.id else { return }
        
        for component in await app.mist.components.getComponents(using: M.self) {
            
            guard component.shouldUpdate(for: model) else { continue }
            guard let html = await component.render(
                id: modelID,
                on: db,
                using: app.leaf.renderer)
            else { continue }
            
            await app.mist.clients.broadcast(
                Message.Update(
                    component: component.name,
                    id: modelID,
                    html: html
                )
            )
        }
    }
    
}
