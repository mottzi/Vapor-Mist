import Vapor

extension Components {
    
    /// Registers components with the runtime, starting model listeners and state publishing.
    func registerComponents(_ components: [any Component]) async {
        
        for component in components {
            if hasComponent(named: component.name) {
                app.logger.warning(
                    "Mist: duplicate component name '\(component.name)' — \(String(describing: type(of: component))) was not registered. Rename one of the components or override var name: String.",
                )
                continue
            }
            let observedModels = (component as? any ModelComponent)?.models ?? []
            
            for model in observedModels where !hasListeners(using: model) {
                model.registerListener(with: app)
            }
            
            componentsByName[component.name] = component
            
            for model in observedModels {
                if let instance = component as? any InstanceComponent {
                    modelToInstanceComponents[ObjectIdentifier(model), default: []].append(instance)
                }
                
                if let fragment = component as? any QueryComponent {
                    modelToQueryComponents[ObjectIdentifier(model), default: []].append(fragment)
                }
            }
            
            if !component.actions.isEmpty {
                componentActions[component.name] = Dictionary(uniqueKeysWithValues: component.actions.map { ($0.name, $0) })
            }
            
            if let task = await startPublishing(for: component) {
                app.lifecycle.use(TaskLifecycleHandler(task: task))
            }
        }
    }
    
}

extension Components {

    func hasListeners(using model: any Model.Type) -> Bool {
        
        let key = ObjectIdentifier(model)
        if modelToInstanceComponents[key] != nil { return true }
        if modelToQueryComponents[key] != nil { return true }
        return false
    }
    
    func hasComponent(named name: String) -> Bool {
        componentsByName[name] != nil
    }
    
    func getComponent(named name: String) -> (any Component)? {
        componentsByName[name]
    }
    
    func getInstanceComponents(using model: any Model.Type) -> [any InstanceComponent] {
        let key = ObjectIdentifier(model)
        return modelToInstanceComponents[key] ?? []
    }
    
    func getQueryComponents(using model: any Model.Type) -> [any QueryComponent] {
        let key = ObjectIdentifier(model)
        return modelToQueryComponents[key] ?? []
    }

    /// Sends the best current fragment state for a new subscriber, reusing polling state when possible.
    func sendCurrentSubscriptionState(for componentName: String, to clientID: UUID) async {
        
        if await sendPollingStateIfAvailable(for: componentName, to: clientID) { return }
        guard let fragment = getComponent(named: componentName) as? any FragmentComponent else { return }
        await fragment.sendCurrent(to: clientID, app: app)
    }

}
