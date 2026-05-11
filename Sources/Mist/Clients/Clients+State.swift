import Vapor

extension Clients {
    
    /// Returns the component state for a client.
    func getState(for clientID: UUID, componentID: String, default defaultState: ComponentState) -> ComponentState {
        clientToComponentState[clientID]?[componentID] ?? defaultState
    }
    
    /// Sets the component state for a client.
    /// When `defaultState` is provided and `state` equals it, the entry is removed rather
    /// than stored — a missing entry already implies the default, so keeping it wastes memory.
    func setState(_ state: ComponentState, for clientID: UUID, componentID: String, default defaultState: ComponentState? = nil) {
        var clientState = clientToComponentState[clientID] ?? [:]
        if let defaultState, state == defaultState {
            clientState.removeValue(forKey: componentID)
        } else {
            clientState[componentID] = state
        }
        clientToComponentState[clientID] = clientState.isEmpty ? nil : clientState
    }

    /// Writes new state only when the current stored value still matches the expected snapshot.
    /// When the resulting state equals `defaultState` the entry is pruned — a missing entry
    /// already implies the default, so keeping a redundant copy wastes memory.
    func setStateIfUnchanged(
        _ newState: ComponentState,
        ifCurrentlyMatches expected: ComponentState,
        for clientID: UUID,
        componentID: String,
        default defaultState: ComponentState
    ) {
        let current = clientToComponentState[clientID]?[componentID] ?? defaultState
        guard current == expected else { return }

        var clientState = clientToComponentState[clientID] ?? [:]
        if newState == defaultState {
            clientState.removeValue(forKey: componentID)
        } else {
            clientState[componentID] = newState
        }
        clientToComponentState[clientID] = clientState.isEmpty ? nil : clientState
    }
    
    /// Clears component state across all clients.
    func clearState(for componentID: String) {
        
        let clientIDs = Array(clientToComponentState.keys)
        
        for clientID in clientIDs {
            var state = clientToComponentState[clientID] ?? [:]
            state.removeValue(forKey: componentID)
            
            switch state.isEmpty {
                case true: clientToComponentState[clientID] = nil
                case false: clientToComponentState[clientID] = state
            }
        }
    }

    /// Clears instance state for clients subscribed to the given component.
    func clearState(for instanceID: String, subscribedTo componentName: String) {
        guard let subscriberIDs = componentToClients[componentName] else { return }

        for clientID in subscriberIDs {
            guard var state = clientToComponentState[clientID] else { continue }
            state.removeValue(forKey: instanceID)
            clientToComponentState[clientID] = state.isEmpty ? nil : state
        }
    }
    
}
