import Vapor
import Fluent

public typealias SendableEncodable = Encodable & Sendable

/// A database model that can be observed and encoded in component rendering.
public protocol Model: Fluent.Model, Sendable where IDValue == UUID {
    
    /// Additional computed values merged with the model's fields.
    var computedProperties: [String: any SendableEncodable] { get }
    
}

public extension Model {
    
    /// Default: a model has no computed template values.
    var computedProperties: [String: any SendableEncodable] { [:] }
    
}

public extension Model {
    
    /// Fetches one model without requiring the concrete model type.
    static func find(id: UUID, on database: Database) async throws -> (any Model)? {
        try await Self.find(id, on: database)
    }

    /// Fetches all models without requiring the concrete model type.
    static func findAll(on database: Database) async throws -> [any Model] {
        try await Self.query(on: database).all()
    }
    
}
