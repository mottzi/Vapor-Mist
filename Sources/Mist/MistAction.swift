import Vapor
import Fluent

public typealias MistActionHandler = @Sendable (UUID, Database) async throws -> ActionResult

public enum ActionResult: Codable, Sendable {
    
    case success
    case failure(message: String)
    case redirect(path: String)
    
}

