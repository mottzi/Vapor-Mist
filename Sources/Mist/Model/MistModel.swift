import Vapor
import Fluent

/// A database model that can be observed and encoded in component rendering.
public protocol MistModel: Fluent.Model where IDValue == UUID {
    
    /// Additional computed values merged with the model's fields.
    var computedProperties: [String: any Encodable] { get }
    
}

public extension MistModel {
    
    /// Default: a model has no computed template values.
    var computedProperties: [String: any Encodable] { [:] }
    
}

public extension MistModel {
    
    /// Fetches one model without requiring the concrete model type.
    static func find(id: UUID, on database: Database) async -> (any MistModel)? {
        try? await Self.find(id, on: database)
    }
    
    /// Fetches all models without requiring the concrete model type.
    static func findAll(on database: Database) async -> [any MistModel]? {
        try? await Self.query(on: database).all()
    }
    
}
