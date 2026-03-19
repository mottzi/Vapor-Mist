import Vapor
import Fluent
import Logging

public protocol Model: Fluent.Model where IDValue == UUID
{
    var contextExtras: [String: any Encodable] { get }
}

public extension Model
{
    var contextExtras: [String: any Encodable] { [:] }
    
    static func find(id: UUID, on database: Database) async -> (any Model)?
    {
        return try? await Self.find(id, on: database)
    }
    
    static func findAll(on database: Database) async -> [any Model]?
    {
        return try? await Self.query(on: database).all()
    }
}

public struct ModelContainer: Encodable
{
    private var models: [String: any Model] = [:]
    
    var hasElements: Bool
    {
        !models.isEmpty
    }

    public mutating func add<M: Model>(_ model: M, for key: String)
    {
        models[key] = model
    }
    
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        for (key, value) in models
        {
            let extras = value.contextExtras
            
            if extras.isEmpty
            {
                try container.encode(value, forKey: StringCodingKey(key))
            }
            else
            {
                let wrapper = MergingEncoder(base: value, extras: extras)
                try container.encode(wrapper, forKey: StringCodingKey(key))
            }
        }
    }
    
    public init() {}
}

public struct SingleComponentContext: Encodable
{
    public let component: ModelContainer
    public let state: MistState
    
    public init(component: ModelContainer, state: MistState)
    {
        self.component = component
        self.state = state
    }
}

public struct MultipleComponentContext: Encodable
{
    public let components: [ModelContainer]
    
    public init(components: [ModelContainer])
    {
        self.components = components
    }
    
    public static var empty: MultipleComponentContext
    {
        .init(components: [])
    }
}
