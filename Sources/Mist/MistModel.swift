import Vapor
import Fluent
import Logging

public protocol Model: Fluent.Model where IDValue == UUID {
    
    /// Override to add dynamic fields for template context
    /// - Returns: A dictionary of additional key-value pairs to expose in Leaf templates
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
    
    /// Default implementation returns empty dictionary
    func contextExtras() -> [String: any Encodable] {
        return [:]
    }

}

// MARK: - Universal AnyEncodable wrapper
fileprivate struct AnyEncodable: Encodable {
    private let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        switch value {
        case is NSNull:
            var container = encoder.singleValueContainer()
            try container.encodeNil()

        case let v as String:
            var container = encoder.singleValueContainer()
            try container.encode(v)

        case let v as Bool:
            var container = encoder.singleValueContainer()
            try container.encode(v)

        case let v as Int:
            var container = encoder.singleValueContainer()
            try container.encode(v)

        case let v as Double:
            var container = encoder.singleValueContainer()
            try container.encode(v)

        case let v as [String: Any]:
            var container = encoder.container(keyedBy: StringCodingKey.self)
            for (key, val) in v {
                try container.encode(AnyEncodable(val), forKey: StringCodingKey(key))
            }

        case let v as [Any]:
            var container = encoder.unkeyedContainer()
            for val in v {
                try container.encode(AnyEncodable(val))
            }

        case let encodable as any Encodable:
            // Handle any other Encodable type
            try encodable.encode(to: encoder)

        default:
            let context = EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Unsupported value type: \(type(of: value))"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}

// MARK: - EncodableWithExtras
fileprivate struct EncodableWithExtras: Encodable {
    let base: any Encodable
    let extras: [String: any Encodable]

    func encode(to encoder: Encoder) throws {
        let logger = Logger(label: "Mist.EncodableWithExtras")
        
        // Step 1: Encode base to JSON
        let baseData = try JSONEncoder().encode(AnyEncodable(base))
        guard var merged = try JSONSerialization.jsonObject(with: baseData) as? [String: Any] else {
            throw EncodingError.invalidValue(base, .init(
                codingPath: encoder.codingPath,
                debugDescription: "Base model did not encode to JSON object"
            ))
        }
        
        logger.warning("📝 Base properties: \(merged.keys.sorted())")

        // Step 2: Merge extras (override if keys collide)
        for (key, value) in extras {
            logger.warning("🔄 Processing extra '\(key)' of type \(type(of: value))")
            
            do {
                let extraData = try JSONEncoder().encode(AnyEncodable(value))
                logger.warning("   Encoded to \(extraData.count) bytes: \(String(data: extraData, encoding: .utf8) ?? "invalid UTF-8")")
                
                let decodedExtra = try JSONSerialization.jsonObject(with: extraData, options: [.allowFragments])
                merged[key] = decodedExtra
                logger.warning("➕ Added extra '\(key)': \(decodedExtra)")
            } catch {
                logger.warning("❌ Failed to process extra '\(key)': \(error)")
                throw error
            }
        }
        
        logger.warning("📋 Final merged properties: \(merged.keys.sorted())")
        
        // Pretty print merged for debugging
        if let prettyData = try? JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            logger.warning("🎨 Merged JSON:\n\(prettyString)")
        }

        // Step 3: Encode merged result back to parent encoder
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in merged {
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
    public func encode(to encoder: Encoder) throws {
        let logger = Logger(label: "Mist.ModelContainer")
        
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        for (key, value) in models {
            // Get extras from the model via protocol method
            let extras = value.contextExtras()
            
            logger.warning("🔑 Encoding model '\(key)' (type: \(type(of: value))) with \(extras.count) extras: \(extras.keys.sorted())")
            
            // Wrap base value together with extras so both get encoded inside the same nested object.
            let wrapper = EncodableWithExtras(base: value, extras: extras)
            try container.encode(wrapper, forKey: StringCodingKey(key))
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

