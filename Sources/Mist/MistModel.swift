import Vapor
import Fluent
import Logging

public protocol Model: Fluent.Model where IDValue == UUID {
    
    func contextExtras() -> [String: any Encodable]
    
}

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
    
    func contextExtras() -> [String: any Encodable] {
        return [:]
    }

}

private struct AnyEncodable: Encodable
{
    private let value: Any

    func encode(to encoder: Encoder) throws 
    {
        switch value 
        {
            case let value as String: try encodePrimitive(value, to: encoder)
            case let value as Bool: try encodePrimitive(value, to: encoder)
            case let value as Int: try encodePrimitive(value, to: encoder)
            case let value as Double: try encodePrimitive(value, to: encoder)
        
            case is NSNull: try encodeNil(to: encoder)
            case let value as [Any]: try encodeArray(value, to: encoder)
            case let value as [String: Any]: try encodeDictionary(value, to: encoder)
            case let value as any Encodable: try value.encode(to: encoder)

            default: throw EncodingError.invalidValue(value, EncodingError.Context(
                    codingPath: encoder.codingPath, 
                    debugDescription: "Unsupported value type: \(type(of: value))"
                )
            )
        }
    }

    init(_ value: Any)
    {
        self.value = value
    }
}

private extension AnyEncodable 
{
    func encodePrimitive<T: Encodable>(_ value: T, to encoder: Encoder) throws 
    {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    func encodeNil(to encoder: Encoder) throws
    {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }

    func encodeArray(_ array: [Any], to encoder: Encoder) throws 
    {
        var container = encoder.unkeyedContainer()
        for item in array {
            try container.encode(AnyEncodable(item))
        }
    }

    func encodeDictionary(_ dict: [String: Any], to encoder: Encoder) throws 
    {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in dict {
            try container.encode(AnyEncodable(value), forKey: StringCodingKey(key))
        }
    }
}

private struct EncodableWithExtras: Encodable
{
    let base: any Encodable
    let extras: [String: any Encodable]

    func encode(to encoder: Encoder) throws
    {
        let logger = Logger(label: "Mist.EncodableWithExtras")
        
        let json = try JSONEncoder().encode(AnyEncodable(base))
        guard var dict = try JSONSerialization.jsonObject(with: json) as? [String: Any] 
        else { throw EncodingError.invalidValue(base, EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Base model did not encode to JSON dictionary"
                )
            )
        }

        logger.warning("📝 Base properties: \(dict.keys.sorted())")

        // add extra properties to dictionary
        for (key, value) in extras 
        {
            logger.warning("🔄 Processing extra '\(key)' of type \(type(of: value))")
            

                switch value 
                {
                    case is String, is Int, is Double, is Bool:
                        dict[key] = value
                        logger.warning("➕ Added primitive extra '\(key)': \(value)")
                    
                    default:
                        guard let extraData = try? JSONEncoder().encode(AnyEncodable(value)),
                              let decodedExtra = try? JSONSerialization.jsonObject(with: extraData, options: [.allowFragments])
                        else {
                            logger.warning("⚠️ Skipping extra '\(key)' - failed to encode")
                            continue
                        }
                        logger.warning("   Encoded to \(extraData.count) bytes: \(String(data: extraData, encoding: .utf8) ?? "invalid UTF-8")")
                        dict[key] = decodedExtra
                        logger.warning("➕ Added complex extra '\(key)': \(decodedExtra)")
                }
        }
        
        logger.warning("📋 Final properties: \(dict.keys.sorted())")
        
        // Pretty print for debugging
        if let prettyData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            logger.warning("🎨 Final JSON:\n\(prettyString)")
        }

        // encode dictionary back to parent encoder
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in dict {
            try container.encode(AnyEncodable(value), forKey: StringCodingKey(key))
        }
    }
}

// container to hold model instances for rendering
public struct ModelContainer: Encodable {
    
    // store model instances keyed by lowercase model type name
    private var models: [String: any Mist.Model] = [:]
    
    var isEmpty: Bool {
        return models.isEmpty
    }

    // add a model instance to the container
    public mutating func add<M: Mist.Model>(_ model: M, for key: String) {
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
                logger.warning("🔑 Encoding model '\(key)' (type: \(type(of: value)) without extras)")
                try container.encode(value, forKey: StringCodingKey(key))
            }
            else
            {
                // merge extras
                logger.warning("🔑 Encoding model '\(key)' (type: \(type(of: value))) with \(extras.count) extras: \(extras.keys.sorted())")
                let wrapper = EncodableWithExtras(base: value, extras: extras)
                try container.encode(wrapper, forKey: StringCodingKey(key))
            }
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

