import Vapor
import Fluent

actor Clients {
    
    static let shared = Clients()
    
    private init() { }
    
    var clients: [Client] = []
    var componentToClients: [String: Set<UUID>] = [:]
    
}

extension Clients {
    
    struct Client {
        
        let id: UUID
        let socket: WebSocket
        var subscriptions: Set<String> = []
        
    }
    
    func addClient(id: UUID, socket: WebSocket) {
        clients.append(Client(id: id, socket: socket))
    }
    
    func removeClient(id: UUID) {
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
    
    func getSubscribers(of component: String) -> [Client] {
        // lookup subscriber IDs from lookup dictionary
        guard let subscriberIDs = componentToClients[component] else { return [] }
        return clients.filter { subscriberIDs.contains($0.id) }
    }
}
    
extension Clients {
    
    @discardableResult func addSubscription(_ component: String, to client: UUID) async -> Bool {

        guard await Components.shared.hasComponent(usingName: component) else { return false }
        guard let index = clients.firstIndex(where: { $0.id == client }) else { return false }
        
        let result = clients[index].subscriptions.insert(component)
        
        // update reverse index
        if result.inserted {
            componentToClients[component, default: []].insert(client)
        }
        
        return result.inserted
    }
}

extension Clients {

    func send(_ message: Mist.Message, to clientID: UUID) async {
        
        guard case .text = message else { return }
        guard let client = clients.first(where: { $0.id == clientID }) else { return }
        guard let jsonData = try? JSONEncoder().encode(message) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        try? await client.socket.send(jsonString)
    }
    
    func broadcast(_ message: Mist.Message) async {
        
        guard case .update(let component, _, _) = message else { return }
        guard let jsonData = try? JSONEncoder().encode(message) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
                
        for subscriber in getSubscribers(of: component) {
            Task { try? await subscriber.socket.send(jsonString) }
        }
    }
}
