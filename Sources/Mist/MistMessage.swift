import Vapor

// Message types for WebSocket communication
enum Message: Codable
{
    case subscribe(component: String)
    case update(component: String, id: UUID?, html: String)
}
