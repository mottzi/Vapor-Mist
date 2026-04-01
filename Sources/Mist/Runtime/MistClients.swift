import Vapor

/// Runtime registry of connected clients, holding subscriptions and per-client component state.
public actor MistClients {
    
    /// Connected clients registered with the runtime.
    var clients: [Client] = []
    
    /// Connected clients subscribed to each component.
    var componentToClients: [String: Set<UUID>] = [:]
    
    /// Per-client state keyed by component name or instance ID.
    var clientToComponentState: [UUID: [String: MistComponentState]] = [:]
    
    /// Reference to the runtime components registry.
    let components: MistComponents
    
    init(components: MistComponents) {
        self.components = components
    }
    
}

extension MistClients {
    
    /// A connected client and its current subscriptions.
    struct Client {
        
        let clientID: UUID
        let socket: WebSocket
        var subscriptions: Set<String> = []
        
    }
    
    /// Adds a client to the registry.
    func addClient(clientID: UUID, socket: WebSocket) {
        clients.append(Client(clientID: clientID, socket: socket))
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
        clientToComponentState[clientID] = nil
    }
    
    /// Returns clients subscribed to a component.
    func getSubscribers(of component: String) -> [Client] {
        guard let subscriberIDs = componentToClients[component] else { return [] }
        return clients.filter { subscriberIDs.contains($0.clientID) }
    }
    
}

extension MistClients {
    
    /// Returns the component state for a client.
    func getState(for clientID: UUID, componentID: String, default defaultState: MistComponentState) -> MistComponentState {
        clientToComponentState[clientID]?[componentID] ?? defaultState
    }
    
    /// Sets the component state for a client.
    func setState(_ state: MistComponentState, for clientID: UUID, componentID: String) {
        var clientState = clientToComponentState[clientID] ?? [:]
        clientState[componentID] = state
        clientToComponentState[clientID] = clientState
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
    
}

extension MistClients {
    
    @discardableResult
    /// Registers a client's subscription to a component.
    func addSubscription(_ component: String, to client: UUID) async -> Bool {
        
        guard await components.hasComponent(named: component) else { return false }
        guard let index = clients.firstIndex(where: { $0.clientID == client }) else { return false }
        
        let result = clients[index].subscriptions.insert(component)
        
        if result.inserted { componentToClients[component, default: []].insert(client) }
        return result.inserted
    }
    
}
