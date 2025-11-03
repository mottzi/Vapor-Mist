import Vapor
import Fluent

extension Mist.Model {

    static func createListener(using config: Mist.Configuration, on db: DatabaseID?) {
        
        config.app.databases.middleware.use(Mist.Listener<Self>(config: config), on: db)
    }
    
}

struct Listener<M: Mist.Model>: AsyncModelMiddleware {
    
    let config: Mist.Configuration
    
    func update(model: M, on db: Database, next: AnyAsyncModelResponder) async throws {
        
        try await next.update(model, on: db)
        
        guard let modelID = model.id else { return }
        
        for component in await Mist.Components.shared.getComponents(using: M.self) {
            
            guard component.shouldUpdate(for: model) else { continue }
            
            guard let html = await component.render(id: modelID, on: db, using: config.app.leaf.renderer) else { continue }
            
            await Mist.Clients.shared.broadcast(
                Message.update(
                    component: component.name,
                    id: modelID,
                    html: html
                )
            )
        }
    }
    
}
