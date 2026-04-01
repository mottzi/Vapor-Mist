import Vapor

/// Runtime registry of components, storing model bindings, actions and more.
public actor Components {
    
    let app: Application
    
    init(app: Application) {
        self.app = app
    }
    
    var componentsByName: [String: any Component] = [:]
    
    var modelToInstanceComponents: [ObjectIdentifier: [any InstanceComponent]] = [:]
    var modelToQueryComponents: [ObjectIdentifier: [any QueryComponent]] = [:]
    
    var componentActions: [String: [String: any Action]] = [:]
    var activeRequests: Set<String> = []
    var suspendedComponents: Set<String> = []
    
}

extension Components {
    
    /// Registers components with the runtime, starting model listeners and state publishing.
    func registerComponents(_ components: [any Component]) async {
        
        for component in components {
            guard !hasComponent(named: component.name) else { continue }
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

}



extension Components {
    
    func suspendUpdates(for component: String) {
        suspendedComponents.insert(component)
    }
    
    func resumeUpdates(for component: String) {
        suspendedComponents.remove(component)
    }
    
    func areUpdatesSuspended(for component: String) -> Bool {
        suspendedComponents.contains(component)
    }
    
    /// Performs a serialized action, temporarily suspending automatic updates if required.
    func performAction(
        _ actionName: String,
        of component: String,
        on targetID: UUID?,
        for clientID: UUID
    ) async -> ActionResult {
        
        let componentKey = targetID?.uuidString ?? component
        let lockKey = "\(clientID.uuidString)-\(componentKey)"

        guard !activeRequests.contains(lockKey) else { return .failure("Action already in progress") }
        activeRequests.insert(lockKey)
        defer { activeRequests.remove(lockKey) }

        guard let componentActions = componentActions[component] else { return .failure("Component '\(component)' not found") }
        guard let action = componentActions[actionName] else { return .failure("Action '\(actionName)' not found") }
        guard let componentInstance = componentsByName[component] else { return .failure("Component '\(component)' not found") }

        let shouldSuspendUpdates = (componentInstance as? any FragmentComponent)?.pausesDuringAction == true
        if shouldSuspendUpdates { suspendUpdates(for: component) }
        defer { if shouldSuspendUpdates { resumeUpdates(for: component) } }

        var state = await app.mist.clients.getState(for: clientID, componentID: componentKey, default: componentInstance.defaultState)
        let result = await action.perform(targetID: targetID, state: &state, app: app)
        await app.mist.clients.setState(state, for: clientID, componentID: componentKey)
        
        return result
    }
    
}

private extension Components {
    
    /// Starts runtime publishing for a component when needed.
    func startPublishing(for component: any Component) async -> Task<Void, Never>? {
        
        switch component {
            case let component as any ManualComponent: await startManualPublishing(for: component)
            case let component as any LiveComponent: await startLivePublishing(for: component)
            case let component as any PollingComponent: startPollingPublishing(for: component)
            default: nil
        }
    }
    
    /// Starts runtime publishing for a manual component.
    func startManualPublishing<C: ManualComponent>(for component: C) async -> Task<Void, Never>? {
        let app = self.app
        
        await component.state.boot(
            render: { await component.render(with: $0, using: app.leaf.renderer) },
            broadcast: { await app.mist.clients.broadcast(Message.QueryUpdate(component: component.name, html: $0)) }
        )
        
        return nil
    }
    
    /// Starts runtime publishing for a live component.
    func startLivePublishing<C: LiveComponent>(for component: C) async -> Task<Void, Never> {
        let app = self.app

        await component.state.boot(
            render: { await component.render(with: $0, using: app.leaf.renderer) },
            broadcast: { await app.mist.clients.broadcast(Message.QueryUpdate(component: component.name, html: $0)) }
        )
        
        return Task.detached { [app] in
            await component.refresh(state: component.state, app: app)

            while !app.didShutdown && !Task.isCancelled {
                try? await Task.sleep(for: component.refreshInterval)
                guard !app.didShutdown && !Task.isCancelled else { break }
                guard await !app.mist.components.areUpdatesSuspended(for: component.name) else { continue }
                await component.refresh(state: component.state, app: app)
            }
        }
    }
    
    /// Starts runtime publishing for a polling component.
    func startPollingPublishing<C: PollingComponent>(for component: C) -> Task<Void, Never> {
        Task.detached { [app] in
            var lastContext: Data?
            
            func tick() async {
                guard !app.didShutdown && !Task.isCancelled else { return }
                
                guard let context = await component.poll(on: app.db) else {
                    guard lastContext != nil else { return }
                    lastContext = nil
                    await app.mist.clients.broadcast(Message.QueryDelete(component: component.name))
                    return
                }

                let encodedContext = try? JSONEncoder().encode(context)
                guard encodedContext != lastContext else { return }
                lastContext = encodedContext

                guard let html = await component.render(with: context, using: app.leaf.renderer) else { return }
                await app.mist.clients.broadcast(Message.QueryUpdate(component: component.name, html: html))
            }

            await tick()
            while !app.didShutdown && !Task.isCancelled {
                try? await Task.sleep(for: component.refreshInterval)
                guard !app.didShutdown && !Task.isCancelled else { break }
                await tick()
            }
        }
    }
    
}

/// Lifecycle handler for runtime tasks, cancelling them on app shutdown.
struct TaskLifecycleHandler: LifecycleHandler {
    
    let task: Task<Void, Never>

    func shutdown(_ app: Application) {
        task.cancel()
    }
    
}
