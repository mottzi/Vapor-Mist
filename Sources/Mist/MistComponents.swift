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
    
    func performAction(component: String, action: String, id: UUID, on db: Database) async -> ActionResult
    {
        guard let componentActions = componentActions[component] else { return .failure(message: "Component '\(component)' not found") }
        guard let action = componentActions[action] else { return .failure(message: "Action '\(action)' not found") }
        return await action.perform(id: id, on: db)
    }
    
}
