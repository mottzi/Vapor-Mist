import Vapor
import Fluent

public actor Clients
{
    var clients: [Client] = []
    var componentToClients: [String: Set<UUID>] = [:]
    let components: Mist.Components
    
    init(components: Mist.Components)
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
        return clients.append(Client(id: id, socket: socket))
    }
    
    func removeClient(id: UUID)
    {
        // abort if client not found in registry
        guard let clientIndex = clients.firstIndex(where: { $0.id == id }) else { return }
        
        // remove client from lookup dictionary
        let clientSubscriptions = clients[clientIndex].subscriptions
        for component in clientSubscriptions {
            guard var subscribers = componentToClients[component] else { continue }
            subscribers.remove(id)
            componentToClients[component] = subscribers.isEmpty ? nil : subscribers
        }
        
        // remove client from registry
        clients.remove(at: clientIndex)
    }
    
    func subscribers(of component: String) -> [Client] {
        // lookup subscriber IDs from lookup dictionary
        guard let subscriberIDs = componentToClients[component] else { return [] }
        return clients.filter { subscriberIDs.contains($0.id) }
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
