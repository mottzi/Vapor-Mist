import Vapor

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

        let snapshot = await app.mist.clients.getState(for: clientID, componentID: componentKey, default: componentInstance.defaultState)
        var state = snapshot
        let result = await action.perform(targetID: targetID, state: &state, app: app)
        await app.mist.clients.setStateIfUnchanged(state, ifCurrentlyMatches: snapshot, for: clientID, componentID: componentKey, default: componentInstance.defaultState)

        if case .success = result {
            await refreshRenderedInstance(
                of: componentInstance,
                modelID: targetID,
                state: state,
                for: clientID
            )
        }
        
        return result
    }

    /// Refreshes the rendered instance for the client after a successful action.
    private func refreshRenderedInstance(
        of component: any Component,
        modelID: UUID?,
        state: ComponentState,
        for clientID: UUID
    ) async {
        guard let modelID else { return }
        guard let instanceComponent = component as? any InstanceComponent else { return }
        guard case .rendered(let html) = await instanceComponent.render(with: modelID, state: state, on: app) else { return }
        await app.mist.clients.send(Message.InstanceUpdate(component: component.name, modelID: modelID, html: html), to: clientID)
    }
    
}
