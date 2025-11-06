import Vapor
import Fluent

extension Mist.Model {
    
    static func registerListener(using config: Configuration) {
        let listener = Listener<Self>(config: config)
        config.app.databases.middleware.use(listener, on: config.db)
    }
    
}

struct Listener<M: Model>: AsyncModelMiddleware {
    
    let config: Configuration
    
    func update(model: M, on db: Database, next: AnyAsyncModelResponder) async throws {
        
        try await next.update(model, on: db)
        
        guard let modelID = model.id else { return }
        
        for component in await Components.shared.components(using: M.self) {
            
            guard component.shouldUpdate(for: model) else { continue }
            guard let html = await component.render(
                id: modelID,
                on: db,
                using: config.app.leaf.renderer)
            else { continue }
            
            await config.app.mist.clients.broadcast(
                Message.Update(
                    component: component.name,
                    id: modelID,
                    html: html
                )
            )
        }
    }
    
}
