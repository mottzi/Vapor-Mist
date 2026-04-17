import Vapor

/// Runtime registry of connected clients, holding subscriptions and per-client component state.
public actor Clients {
    
    /// Connected clients registered with the runtime.
    var clients: [Client] = []

    /// Connected clients indexed by identifier for direct lookup.
    var clientsByID: [UUID: Client] = [:]
    
    /// Connected clients subscribed to each component.
    var componentToClients: [String: Set<UUID>] = [:]
    
    /// Per-client state keyed by component name or instance ID.
    var clientToComponentState: [UUID: [String: ComponentState]] = [:]
    
    /// Reference to the runtime components registry.
    let components: Components

    /// Logger for runtime diagnostics.
    let logger: Logger

    init(components: Components, logger: Logger) {
        self.components = components
        self.logger = logger
    }
    
}

extension Clients {
    
    /// A connected client and its current subscriptions.
    struct Client {
        
        let clientID: UUID
        let socket: WebSocket
        var subscriptions: Set<String> = []
        
    }
    
    /// Adds a client to the registry.
    func addClient(clientID: UUID, socket: WebSocket) {
        let client = Client(clientID: clientID, socket: socket)
        clients.append(client)
        clientsByID[clientID] = client
    }
    
    /// Removes a client from the registry and clears its runtime state.
    func removeClient(clientID: UUID) {
        
        guard let clientIndex = clients.firstIndex(where: { $0.clientID == clientID }) else { return }
        
        for component in clients[clientIndex].subscriptions {
            guard var subscribers = componentToClients[component] else { continue }
            subscribers.remove(clientID)
            componentToClients[component] = subscribers.isEmpty ? nil : subscribers
        }
        
        clients.remove(at: clientIndex)
        clientsByID[clientID] = nil
        clientToComponentState[clientID] = nil
    }
    
    /// Returns clients subscribed to a component.
    func getSubscribers(of component: String) -> [Client] {
        guard let subscriberIDs = componentToClients[component] else { return [] }
        return subscriberIDs.compactMap { clientsByID[$0] }
    }
    
}

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

extension Clients {
    
    @discardableResult
    /// Registers a client's subscription to a component.
    func addSubscription(_ component: String, to client: UUID) async -> Bool {
        
        guard await components.hasComponent(named: component) else { return false }
        guard let index = clients.firstIndex(where: { $0.clientID == client }) else { return false }
        
        let result = clients[index].subscriptions.insert(component)
        clientsByID[client] = clients[index]
        
        if result.inserted { componentToClients[component, default: []].insert(client) }
        return result.inserted
    }
    
}
