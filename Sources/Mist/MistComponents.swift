import Vapor
import Fluent

actor Components {
    
    static let shared = Components()
    
    private init() {}
    
    private var components: [any Mist.Component] = []
    
    func registerComponents(definedIn config: Mist.Configuration) async {
        
        for component in config.components {
            
            guard components.contains(where: { $0.name == component.name }) == false else { continue }
            
            for model in component.models {
                
                guard components.contains(where: { $0.models.contains { $0 == model } }) == false else { continue }
                
                model.createListener(using: config, on: config.db)
            }
            
            components.append(component)
        }
    }
    
    func getComponents<M: Mist.Model>(using model: M.Type) -> [any Mist.Component] {
        return components.filter { $0.models.contains { $0 == model } }
    }
    
    func hasComponent(name: String) -> Bool {
        return components.contains { $0.name == name }
    }
    
}

#if DEBUG
extension Mist.Components {
    
    func registerWOListenerForTesting(_ component: any Mist.Component) {
        guard components.contains(where: { $0.name == component.name }) == false else { return }
        components.append(component)
    }
    
    func getStorgeForTesting() async -> [any Mist.Component] {
        return components
    }
    
    func resetForTesting() async {
        components = []
    }
    
}
#endif
