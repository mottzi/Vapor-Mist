import Vapor
import Fluent

actor Components {
    
    static let shared = Components()
    
    private init() {}
    
    var components: [any Mist.Component] = []
    
}

extension Mist.Components {
    
    func registerComponents(using config: Mist.Configuration) async {
        
        for component in config.components {
            
            guard hasComponent(usingName: component.name) == false else { continue }
            
            for model in component.models {
                
                guard hasComponent(usingModel: model) == false else { continue }
                model.registerListener(using: config)
            }
            
            components.append(component)
        }
    }
    
    func components<M: Mist.Model>(using model: M.Type) -> [any Mist.Component] {
        return components.filter { $0.models.contains { $0 == model } }
    }
    
    func hasComponent(usingName name: String) -> Bool {
        return components.contains { $0.name == name }
    }
    
    func hasComponent(usingModel model: any Model.Type) -> Bool {
        return components.contains { $0.models.contains { $0 == model } }
    }
    
}
