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

// Type-erased encodable wrapper
private struct AnyEncodable: Encodable {
    
    private let _encode: (Encoder) throws -> Void
    
    init(_ encodable: any Encodable) {
        _encode = encodable.encode(to:)
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
    
}

// Wrapper that combines a model and its context extras
private struct ModelWithExtras: Encodable {
    
    let model: any Mist.Model
    let extras: [String: any Encodable]
    
    func encode(to encoder: Encoder) throws {
        let logger = Logger(label: "Mist")
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        
        // First, capture the model's encoded representation
        let modelEncoder = DictionaryEncoder()
        try model.encode(to: modelEncoder)
        
        // Encode model properties
        for (key, value) in modelEncoder.data {
            let codingKey = DynamicCodingKey(stringValue: key)
            try container.encode(AnyEncodable(value), forKey: codingKey)
        }
        
        // Encode extras
        for (key, value) in extras {
            let codingKey = DynamicCodingKey(stringValue: key)
            try container.encode(AnyEncodable(value), forKey: codingKey)
        }
        
        // Log the final structure
        let allKeys = modelEncoder.data.keys.sorted() + extras.keys.sorted()
        logger.warning("[\(type(of: model))] Encoded with properties: \(allKeys.joined(separator: ", "))")
    }
    
}

// Custom encoder that captures key-value pairs
private class DictionaryEncoder: Encoder {
    
    var data: [String: any Encodable] = [:]
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = DictionaryKeyedEncodingContainer<Key>(encoder: self)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("Unkeyed encoding not supported")
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError("Single value encoding not supported")
    }
    
}

private struct DictionaryKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    
    let encoder: DictionaryEncoder
    var codingPath: [CodingKey] = []
    
    mutating func encodeNil(forKey key: Key) throws {
        // Skip nil values
    }
    
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        encoder.data[key.stringValue] = value
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        fatalError("Nested encoding not supported")
    }
    
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        fatalError("Nested encoding not supported")
    }
    
    mutating func superEncoder() -> Encoder {
        fatalError("Super encoder not supported")
    }
    
    mutating func superEncoder(forKey key: Key) -> Encoder {
        fatalError("Super encoder not supported")
    }
    
}

// Dynamic coding key
private struct DynamicCodingKey: CodingKey {
    
    var stringValue: String
    var intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
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
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        for (key, model) in models {
            // Get extras from the model and merge with base model properties
            let extras = model.contextExtras()
            let wrapper = ModelWithExtras(model: model, extras: extras)
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

