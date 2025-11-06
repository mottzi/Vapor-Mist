import Vapor
import Fluent

actor Components {
    
    static let shared = Components()
    
    private init() {}
    
    var components: [any Mist.Component] = []
    var modelToComponents: [ObjectIdentifier: [any Mist.Component]] = [:]
    
}

extension Mist.Components {
    
    func registerComponents(_ components: [any Mist.Component], with app: Application) async
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
    
}
