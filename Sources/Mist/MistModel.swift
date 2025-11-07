import Vapor
import Fluent
import Logging

public protocol Model: Fluent.Model where IDValue == UUID {}

public extension Mist.Model {

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
    
    /// Override to add dynamic fields for template context
    /// - Returns: A dictionary of additional key-value pairs to expose in Leaf templates
    func contextExtras() -> [String: any Encodable] {
        return [:]
    }

}

// container to hold model instances for rendering
public struct ModelContainer: Encodable {
    
    // store encodable model data keyed by lowercase model type name
    private var models: [String: any Encodable] = [:]
    
    var isEmpty: Bool {
        return models.isEmpty
    }

    // add a model instance to the container
    public mutating func add<M: Mist.Model>(_ model: M, for key: String) {
        models[key] = model
    }
    
    // flattens the models dictionary when encoding, making properties directly accessible in template
    public func encode(to encoder: Encoder) throws {
        let logger = Logger(label: "Mist")
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        logger.warning("ModelContainer.encode: Starting encoding for \(models.count) models")
        
        for (key, value) in models {
            logger.warning("ModelContainer.encode: Encoding model with key '\(key)'")
            
            // First encode the base model
            try container.encode(value, forKey: StringCodingKey(key))
            logger.warning("ModelContainer.encode: Base model '\(key)' encoded successfully")
            
            // Then encode extras if the model provides them
            if let model = value as? any Mist.Model {
                logger.warning("ModelContainer.encode: Model '\(key)' is a Mist.Model, checking for extras")
                let extras = model.contextExtras()
                logger.warning("ModelContainer.encode: Model '\(key)' returned \(extras.count) extras: \(extras.keys.joined(separator: ", "))")
                
                if !extras.isEmpty {
                    var sub = container.nestedContainer(keyedBy: StringCodingKey.self, forKey: StringCodingKey(key))
                    for (extraKey, extraValue) in extras {
                        logger.warning("ModelContainer.encode: Encoding extra '\(extraKey)' for model '\(key)'")
                        try sub.encode(extraValue, forKey: StringCodingKey(extraKey))
                        logger.warning("ModelContainer.encode: Extra '\(extraKey)' encoded successfully")
                    }
                }
            } else {
                logger.warning("ModelContainer.encode: Model '\(key)' is NOT a Mist.Model (type: \(type(of: value)))")
            }
        }
        
        logger.warning("ModelContainer.encode: Encoding completed")
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
