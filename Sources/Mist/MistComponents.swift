import Vapor
import Fluent

// thread-safe component registry
actor Components
{
    static let shared = Components()
    private init() { }
    
    // mist component storage (native existential type)
    private var components: [any Component] = []
    
    // retrieve all components that use a specific model
    func getComponents<M: Mist.Model>(using model: M.Type) -> [any Component] {
        components.filter { $0.models.contains { $0 == model } }
    }
    
    // checks if component with given name exists
    func hasComponent(name: String) -> Bool
    {
        return components.contains { $0.name == name }
    }
}

extension Components
{
    // initialize component system
    func registerComponents(definedIn config: Mist.Configuration) async
    {
        // register configured components
        for component in config.components
        {
            // abort if component name is already registered
            guard components.contains(where: { $0.name == component.name }) == false else { continue }
            
            // register database listeners for component models
            for model in component.models {
                // skip if component using this model has already been registered
                guard components.contains(where: { $0.models.contains { $0 == model } }) == false else { continue }
                
                // register db model listener middleware for new models
                model.createListener(using: config, on: config.db)
            }
            
            // add component instance to storage
            components.append(component)
        }
    }
}

#if DEBUG
extension Components
{
    func registerWOListenerForTesting(_ component: any Mist.Component)
    {
        // abort if component name is already registered
        guard components.contains(where: { $0.name == component.name }) == false else { return }
        
        // add component instance to storage
        components.append(component)
    }
    
    func getStorgeForTesting() async -> [any Mist.Component]
    {
        return components
    }
    
    func resetForTesting() async
    {
        components = []
    }
}
#endif
