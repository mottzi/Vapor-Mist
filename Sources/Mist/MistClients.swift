import Vapor
import Fluent

actor Clients {
    
    static let shared = Clients()
    
    private init() { }
    
    private var clients: [Client] = []
    
}

extension Clients {
    
    struct Client {
        
        let id: UUID
        let socket: WebSocket
        var subscriptions: Set<String> = []
        
    }
    
    func add(client id: UUID, socket: WebSocket) {
        
        clients.append(Client(id: id, socket: socket))
    }
    
    func remove(client id: UUID) {
        
        clients.removeAll { $0.id == id }
    }
    
    func getClients() -> [Client] {

        return clients
    }
    
    func getSubscribers(of component: String) -> [Client] {
        
        return clients.filter { $0.subscriptions.contains(component) }
    }
}
    
extension Clients {
    
    @discardableResult func addSubscription(_ component: String, to client: UUID) async -> Bool {

        guard await Components.shared.hasComponent(name: component) else { return false }
        
        guard let index = clients.firstIndex(where: { $0.id == client }) else { return false }
        
        let result = clients[index].subscriptions.insert(component)
        
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

#if DEBUG
extension Clients {
    
    func resetForTesting() async {
        clients = []
    }
    
}
#endif
