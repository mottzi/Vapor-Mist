import Vapor
import Fluent

public protocol Action: Sendable {
    
    var name: String { get }
    
    func perform(id: UUID, on db: Database) async -> ActionResult
    
}

public extension Action {
    
    var name: String { String(describing: Self.self) }
    
}

public enum ActionResult: Codable, Sendable {
    
    case success(message: String? = nil)
    case failure(message: String? = nil)
    
}
