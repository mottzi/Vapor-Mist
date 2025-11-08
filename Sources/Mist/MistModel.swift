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

// Wrapper that combines a model and its context extras
private struct ModelWithExtras: Encodable {
    
    let model: any Mist.Model
    let extras: [String: any Encodable]
    
    func encode(to encoder: Encoder) throws {
        let logger = Logger(label: "Mist")
        
        // Step 1: Encode model to JSON
        let jsonEncoder = JSONEncoder()
        guard let modelData = try? jsonEncoder.encode(model) else {
            throw EncodingError.invalidValue(model, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Failed to encode model"
            ))
        }
        
        // Step 2: Decode JSON to dictionary
        guard let modelDict = try? JSONSerialization.jsonObject(with: modelData) as? [String: Any] else {
            throw EncodingError.invalidValue(model, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Failed to decode model JSON"
            ))
        }
        
        // Step 3: Merge extras into dictionary
        var mergedDict = modelDict
        for (key, value) in extras {
            // Try to encode the extra value to JSON
            do {
                let extraData = try jsonEncoder.encode(value)
                let extraValue = try JSONSerialization.jsonObject(with: extraData)
                mergedDict[key] = extraValue
            } catch {
                // Fallback: use the value directly if it's a basic type
                if let string = value as? String {
                    mergedDict[key] = string
                } else if let int = value as? Int {
                    mergedDict[key] = int
                } else if let double = value as? Double {
                    mergedDict[key] = double
                } else if let bool = value as? Bool {
                    mergedDict[key] = bool
                }
            }
        }
        
        // Log result
        logger.warning("[\(type(of: model))] Encoded with properties: \(mergedDict.keys.sorted().joined(separator: ", "))")
        
        // Step 4: Encode merged dictionary
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in mergedDict {
            try encodeAnyValue(value, forKey: StringCodingKey(key), in: &container)
        }
    }
    
    private func encodeAnyValue(_ value: Any, forKey key: StringCodingKey, in container: inout KeyedEncodingContainer<StringCodingKey>) throws {
        switch value {
        case let string as String:
            try container.encode(string, forKey: key)
        case let int as Int:
            try container.encode(int, forKey: key)
        case let double as Double:
            try container.encode(double, forKey: key)
        case let bool as Bool:
            try container.encode(bool, forKey: key)
        case is NSNull:
            try container.encodeNil(forKey: key)
        default:
            try container.encode(String(describing: value), forKey: key)
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

