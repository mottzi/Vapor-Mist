import Vapor
import Fluent

public protocol Model: Fluent.Model where IDValue == UUID {}

public extension Mist.Model {

    static var find: (UUID, Database) async -> (any Mist.Model)? {
        return { id, db in
            return try? await Self.find(id, on: db)
        }
    }
    
    static var findAll: (Database) async -> [any Mist.Model]? {
        return { db in
            return try? await Self.query(on: db).all()
        }
    }

}

// container to hold model instances for rendering
public struct ModelContainer: Encodable {
    
    // store encodable model data keyed by lowercase model type name
    private var models: [String: any Encodable] = [:]
    
    var isEmpty: Bool {
        return models.isEmpty
    }

    // Add a model instance to the container
    public mutating func add<M: Mist.Model>(_ model: M, for key: String) {
        models[key] = model
    }
    
    // flattens the models dictionary when encoding, making properties directly accessible in template
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        for (key, value) in models {
            try container.encode(value, forKey: StringCodingKey(key))
        }
    }
    
    public init() {}
    
}

private struct StringCodingKey: CodingKey {
    
    public var stringValue: String
    public var intValue: Int?
    
    public init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }
    
    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    public init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
    
}

public struct SingleComponentContext: Encodable {
    
    let component: ModelContainer
    
    public init(component: ModelContainer) {
        self.component = component
    }
    
}

public struct MultipleComponentContext: Encodable {
    
    let components: [ModelContainer]
    
    public init(components: [ModelContainer]) {
        self.components = components
    }
    
    public static var empty: MultipleComponentContext {
        .init(components: [])
    }
    
}
