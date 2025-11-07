import Vapor
import Fluent

public protocol Action: Sendable {
    
    var name: String { get }
    
    func execute(id: UUID, on db: Database) async throws -> ActionResult
    
}

public extension Action {
    
    var name: String { String(describing: Self.self) }
    
}

public enum ActionResult: Codable, Sendable {
    
    case success
    case failure(message: String)
    case redirect(path: String)
    
}

