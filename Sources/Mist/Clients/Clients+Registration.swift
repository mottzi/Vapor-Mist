import Vapor

extension Clients {
    
    /// A connected client and its current subscriptions.
    struct Client {
        
        let clientID: UUID
        let socket: WebSocket
        var subscriptions: Set<String> = []
        
    }
    
    /// Adds a client to the registry.
    func addClient(clientID: UUID, socket: WebSocket) {
        disconnectedAt[clientID] = nil
        
        if let existingIndex = clients.firstIndex(where: { $0.clientID == clientID }) {
            clients.remove(at: existingIndex)
        }
        
        let client = Client(clientID: clientID, socket: socket)
        clients.append(client)
        clientsByID[clientID] = client
    }
    
    /// Removes a client from the registry.
    func removeClient(clientID: UUID) {
        
        guard let clientIndex = clients.firstIndex(where: { $0.clientID == clientID }) else { return }
        
        for component in clients[clientIndex].subscriptions {
            guard var subscribers = componentToClients[component] else { continue }
            subscribers.remove(clientID)
            componentToClients[component] = subscribers.isEmpty ? nil : subscribers
        }
        
        clients.remove(at: clientIndex)
        clientsByID[clientID] = nil
        
        disconnectedAt[clientID] = Date()
        purgeStaleStates()
    }

    /// Purges component state for clients that have been disconnected for longer than the grace period.
    func purgeStaleStates(gracePeriod: TimeInterval = 60) {
        let now = Date()
        let staleIDs = disconnectedAt.filter { now.timeIntervalSince($1) > gracePeriod }.map { $0.key }
        
        for id in staleIDs {
            clientToComponentState[id] = nil
            disconnectedAt[id] = nil
        }
    }
    
    /// Returns clients subscribed to a component.
    func getSubscribers(of component: String) -> [Client] {
        guard let subscriberIDs = componentToClients[component] else { return [] }
        return subscriberIDs.compactMap { clientsByID[$0] }
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
