import Vapor
import Fluent

public typealias MistClients = Clients

public actor Clients
{
    var clients: [Client] = []
    var componentToClients: [String: Set<UUID>] = [:]
    var sessionState: [UUID: [String: MistState]] = [:]
    
    let components: Components
    
    init(components: Components)
    {
        self.components = components
    }
}

extension Clients
{
    struct Client
    {
        let id: UUID
        let socket: WebSocket
        var subscriptions: Set<String> = []
    }
    
    func addClient(id: UUID, socket: WebSocket)
    {
        clients.append(Client(id: id, socket: socket))
    }
    
    func removeClient(id: UUID)
    {
        guard let clientIndex = clients.firstIndex(where: { $0.id == id }) else { return }
        
        for component in clients[clientIndex].subscriptions
        {
            guard var subscribers = componentToClients[component] else { continue }
            subscribers.remove(id)
            componentToClients[component] = subscribers.isEmpty ? nil : subscribers
        }
        
        clients.remove(at: clientIndex)
        sessionState[id] = nil
    }
    
    func subscribers(of component: String) -> [Client]
    {
        guard let subscriberIDs = componentToClients[component] else { return [] }
        return clients.filter { subscriberIDs.contains($0.id) }
    }
}

extension Clients
{
    func state(for clientID: UUID, componentID: String, default defaultState: MistState) -> MistState
    {
        return sessionState[clientID]?[componentID] ?? defaultState
    }
    
    func setState(_ state: MistState, for clientID: UUID, componentID: String)
    {
        var clientState = sessionState[clientID] ?? [:]
        clientState[componentID] = state
        sessionState[clientID] = clientState
    }
    
    func clearState(for componentID: String)
    {
        let clientIDs = Array(sessionState.keys)
        for clientID in clientIDs
        {
            var state = sessionState[clientID] ?? [:]
            state.removeValue(forKey: componentID)
            
            switch state.isEmpty
            {
                case true: sessionState[clientID] = nil
                case false: sessionState[clientID] = state
            }
        }
    }
}

extension Clients
{
    @discardableResult
    func addSubscription(_ component: String, to client: UUID) async -> Bool
    {
        guard await components.hasComponent(usingName: component) else { return false }
        guard let index = clients.firstIndex(where: { $0.id == client }) else { return false }
        
        let result = clients[index].subscriptions.insert(component)
        
        if result.inserted { componentToClients[component, default: []].insert(client) }
        
        return result.inserted
    }
}
