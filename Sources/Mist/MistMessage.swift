import Vapor

// Message types for WebSocket communication
enum Message: Codable
{
    case text(_ message: String)
    case subscribe(component: String)
    case update(component: String, id: UUID?, html: String)
}
