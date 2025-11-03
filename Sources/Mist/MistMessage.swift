import Vapor

enum Message: Codable
{
    case text(message: String)
    case subscribe(component: String)
    case update(component: String, id: UUID?, html: String)
}

protocol ServerMessage {
    func prepareMessage() -> Mist.Message
}

enum TextMessage: ServerMessage {
    case text(message: String)
    
    func prepareMessage() -> Mist.Message {
        guard case TextMessage.text(let msg) = self else { fatalError() }
        return Message.text(message: msg)
    }
}

enum UpdateMessage: ServerMessage {
    case update(component: String, id: UUID?, html: String)
    
    func prepareMessage() -> Mist.Message {
        guard case UpdateMessage.update(let component, let id, let html) = self else { fatalError() }
        return Message.update(component: component, id: id, html: html)
    }
}
