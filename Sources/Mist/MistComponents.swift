import Vapor
import Fluent

public actor Components {
        
    var components: [any Mist.Component] = []
    var modelToComponents: [ObjectIdentifier: [any Mist.Component]] = [:]
    var componentActions: [String: [String: any Action]] = [:]
    
    init() {}

}

extension Mist.Components {
    
    func registerComponents(_ components: [any Mist.Component], with app: Application)
    {
        for component in components
        {
            guard !hasComponent(usingName: component.name) else { continue }
            
            for model in component.models
            {
                guard !hasComponent(usingModel: model) else { continue }
                model.registerListener(with: app)
            }
            
            self.components.append(component)
            
            for model in component.models
            {
                let key = ObjectIdentifier(model)
                modelToComponents[key, default: []].append(component)
            }
            
            if !component.actions.isEmpty
            {
                componentActions[component.name] = Dictionary(uniqueKeysWithValues: component.actions.map { ($0.name, $0) })
            }
        }
    }
    
    func getComponents<M: Mist.Model>(using model: M.Type) -> [any Mist.Component]
    {
        let key = ObjectIdentifier(M.self)
        return modelToComponents[key] ?? []
    }
    
    func hasComponent(usingName name: String) -> Bool
    {
        return components.contains { $0.name == name }
    }
    
    func hasComponent(usingModel model: any Model.Type) -> Bool
    {
        let key = ObjectIdentifier(model)
        return modelToComponents[key] != nil
    }
    
    func executeAction(component: String, action: String, id: UUID, on db: Database) async throws -> ActionResult
    {
        guard let componentActionHandlers = componentActions[component] else
        {
            throw Abort(.notFound, reason: "Component '\(component)' not found")
        }
        
        guard let actionInstance = componentActionHandlers[action] else
        {
            throw Abort(.notFound, reason: "Action '\(action)' not found for component '\(component)'")
        }
        
        return try await actionInstance.execute(id: id, on: db)
    }
    
}
