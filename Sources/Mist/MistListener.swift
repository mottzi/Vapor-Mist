import Vapor
import Fluent

extension Mist.Model
{
    // registers db middleware listener on Fluent db changes
    static func createListener(using config: Mist.Configuration, on db: DatabaseID?)
    {
        config.app.databases.middleware.use(Mist.Listener<Self>(config: config), on: db)
    }
}

// generic database model update listener
struct Listener<M: Mist.Model>: AsyncModelMiddleware
{
    let config: Mist.Configuration
    
    // update callback
    func update(model: M, on db: Database, next: AnyAsyncModelResponder) async throws
    {        
        // perform middleware chain
        try await next.update(model, on: db)
        
        // Ensure we have a UUID
        guard let modelID = model.id else { return }
        
        // get type-safe components registered for this model type
        let components = await Mist.Components.shared.getComponents(using: M.self)
        
        // process each component
        for component in components
        {
            await renderComponent(component, for: model, modelID: modelID, db: db, renderer: config.app.leaf.renderer)
        }
    }
    
    // Process a single component and broadcast update if needed
    private func renderComponent(_ component: any Mist.Component, for model: M, modelID: UUID, db: Database, renderer: ViewRenderer) async
    {
        // Only update if component says it should
        guard component.shouldUpdate(for: model) else { return }
             
        // render using ID and database OR test update
        guard let html = await component.render(id: modelID, on: db, using: renderer) else { return }
         
        // broadcast to all connected clients
        await Mist.Clients.shared.broadcast(.update(
            component: component.name,
            id: modelID,
            html: html
        ))
    }
}
