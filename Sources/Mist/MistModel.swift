import Vapor
import Fluent
import Logging

public protocol Model: Fluent.Model where IDValue == UUID
{
    func contextExtras() -> [String: any Encodable]
}

public extension Mist.Model
{
    func contextExtras() -> [String: any Encodable]
    {
        return [:]
    }
}

public extension Mist.Model
{
    static var find: (UUID, Database) async -> (any Mist.Model)?
    {
        return { id, db in
            return try? await Self.find(id, on: db)
        }
    }
    
    static var findAll: (Database) async -> [any Mist.Model]?
    {
        return { db in
            return try? await Self.query(on: db).all()
        }
    }
}

public struct ModelContainer: Encodable
{
    private var models: [String: any Mist.Model] = [:]
    
    var isEmpty: Bool
    {
        return models.isEmpty
    }

    public mutating func add<M: Mist.Model>(_ model: M, for key: String)
    {
        models[key] = model
    }
    
    // flattens the models dictionary when encoding, making properties directly accessible in template
    public func encode(to encoder: Encoder) throws
    {
        let logger = Logger(label: "Mist.ModelContainer")
        
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        for (key, value) in models
        {
            // Get extras from the model via protocol method
            let extras = value.contextExtras()
            
            if extras.isEmpty
            {
                // direct encoding
                logger.warning("Encoding model '\(key)' (type: \(type(of: value))) without extras")
                try container.encode(value, forKey: StringCodingKey(key))
            }
            else
            {
                // merge extras
                logger.warning("Encoding model '\(key)' (type: \(type(of: value))) with \(extras.count) extras: \(extras.keys.sorted())")
                let wrapper = MergingEncoder(base: value, extras: extras)
                try container.encode(wrapper, forKey: StringCodingKey(key))
            }
        }
    }
    
    public init() {}
}

public struct SingleComponentContext: Encodable
{
    let component: ModelContainer
    
    public init(component: ModelContainer)
    {
        self.component = component
    }
}

public struct MultipleComponentContext: Encodable
{
    let components: [ModelContainer]
    
    public init(components: [ModelContainer])
    {
        self.components = components
    }
    
    public static var empty: MultipleComponentContext
    {
        .init(components: [])
    }
}
