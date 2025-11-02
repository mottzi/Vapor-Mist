import Vapor
import Fluent

// mist models are fluent models that use UUID as id
public protocol Model: Fluent.Model where IDValue == UUID {}

// type-erased fluent model for mist db operations
public extension Model
{
    // type-erased find function as closure that captures concrete model type
    static var find: (UUID, Database) async -> (any Mist.Model)?
    {
        let closure = { id, db in
            // Use Self to refer to the concrete model type
            return try? await Self.find(id, on: db)
        }
        
        return closure
    }
    
    // type-erased findAll() function as closure that captures concrete model type
    static var findAll: (Database) async -> [any Mist.Model]?
    {
        let closure = { db in
            // Use Self to refer to the concrete model type
            return try? await Self.query(on: db).all()
        }
        
        return closure
    }
}

// container to hold model instances for rendering
public struct ModelContainer: Encodable
{
    // store encodable model data keyed by lowercase model type name
    private var models: [String: Encodable] = [:]
    
    var isEmpty: Bool { return models.isEmpty }

    // Add a model instance to the container
    public mutating func add<M: Mist.Model>(_ model: M, for key: String)
    {
        models[key] = model
    }
    
    // flattens the models dictionary when encoding, making properties directly accessible in template
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        for (key, value) in models
        {
            try container.encode(value, forKey: StringCodingKey(key))
        }
    }
    
    public init() {}
}

// helper struct for string-based coding keys
private struct StringCodingKey: CodingKey
{
    public var stringValue: String
    public var intValue: Int?
    
    public init(_ string: String)
    {
        self.stringValue = string
        self.intValue = nil
    }
    
    public init?(stringValue: String)
    {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    public init?(intValue: Int)
    {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// single context
public struct SingleComponentContext: Encodable
{
    let component: ModelContainer
    
    public init(component: ModelContainer) { self.component = component }
}

// collection context
public struct MultipleComponentContext: Encodable
{
    let components: [ModelContainer]
    
    public init(components: [ModelContainer]) { self.components = components }
    
    public static var empty: MultipleComponentContext { .init(components: []) }
}
