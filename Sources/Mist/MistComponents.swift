import Vapor
import Fluent

actor Components {
    
    static let shared = Components()
    
    private init() {}
    
    var components: [any Mist.Component] = []
    var modelToComponents: [ObjectIdentifier: [any Mist.Component]] = [:]
    
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
            
            // Populate reverse index for O(1) model-to-component lookup
            for model in component.models {
                let key = ObjectIdentifier(model)
                modelToComponents[key, default: []].append(component)
            }
        }
    }
    
    func components<M: Mist.Model>(using model: M.Type) -> [any Mist.Component] {
        let key = ObjectIdentifier(M.self)
        return modelToComponents[key] ?? []
    }
    
    func hasComponent(usingName name: String) -> Bool {
        return components.contains { $0.name == name }
    }
    
    func hasComponent(usingModel model: any Model.Type) -> Bool {
        return components.contains { $0.models.contains { $0 == model } }
    }
    
}
