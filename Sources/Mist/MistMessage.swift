import Vapor

enum Message: Codable {
    
    case text(message: String)
    
    case subscribe(component: String)
    
    case update(component: String, id: UUID?, html: String)
    
    case action(component: String, id: UUID, action: String)
    
    case actionResult(component: String, id: UUID, action: String, result: Mist.ActionResult, message: String)
    
}

extension Clients {
    
    func send(_ message: Message.Text, to clientID: UUID) async {
        
        guard let client = clients.first(where: { $0.id == clientID }) else { return }
        guard let jsonData = try? JSONEncoder().encode(message.wireFormat) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        try? await client.socket.send(jsonString)
    }
    
    func send(_ message: Message.ActionResult, to clientID: UUID) async {
        
        guard let client = clients.first(where: { $0.id == clientID }) else { return }
        guard let jsonData = try? JSONEncoder().encode(message.wireFormat) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        try? await client.socket.send(jsonString)
    }
    
    func broadcast(_ message: Message.Update) async {
        
        guard let jsonData = try? JSONEncoder().encode(message.wireFormat) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        for subscriber in subscribers(of: message.component) {
            Task { try? await subscriber.socket.send(jsonString) }
        }
    }
    
}

extension Message {
    
    struct Text {
        
        let message: String
        
        var wireFormat: Message {
            .text(message: message)
        }
        
        init(_ message: String) {
            self.message = message
        }
        
    }
    
    struct Update {
        
        let component: String
        let id: UUID?
        let html: String
        
        var wireFormat: Message {
            .update(component: component, id: id, html: html)
        }
        
    }
    
    struct ActionResult {
        
        let component: String
        let id: UUID
        let action: String
        let result: Mist.ActionResult
        let message: String
        
        var wireFormat: Message {
            .actionResult(component: component, id: id, action: action, result: result, message: message)
        }
        
    }
    
}
