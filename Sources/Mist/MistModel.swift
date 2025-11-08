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
        
        logger.warning("ModelWithExtras.encode: Starting to encode model type: \(type(of: model))")
        logger.warning("ModelWithExtras.encode: Extras to add: \(extras.keys.sorted().joined(separator: ", "))")
        
        // Step 1: Encode model to JSON
        let jsonEncoder = JSONEncoder()
        guard let modelData = try? jsonEncoder.encode(model) else {
            logger.warning("ModelWithExtras.encode: Failed to encode model to JSON")
            throw EncodingError.invalidValue(model, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Failed to encode model"
            ))
        }
        
        // Step 2: Decode JSON to dictionary
        guard let modelDict = try? JSONSerialization.jsonObject(with: modelData) as? [String: Any] else {
            logger.warning("ModelWithExtras.encode: Failed to decode model JSON to dictionary")
            throw EncodingError.invalidValue(model, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Failed to decode model JSON"
            ))
        }
        
        logger.warning("ModelWithExtras.encode: Model has \(modelDict.count) base properties")
        
        // Step 3: Merge extras into dictionary
        var mergedDict = modelDict
        for (key, value) in extras.sorted(by: { $0.key < $1.key }) {
            logger.warning("ModelWithExtras.encode: Adding extra '\(key)' = '\(value)' (type: \(type(of: value)))")
            
            // Encode the extra value to JSON to get its Any representation
            do {
                let extraData = try jsonEncoder.encode(value)
                logger.warning("ModelWithExtras.encode: Encoded to JSON data: \(extraData.count) bytes")
                
                let extraValue = try JSONSerialization.jsonObject(with: extraData)
                logger.warning("ModelWithExtras.encode: Deserialized to: \(extraValue) (type: \(type(of: extraValue)))")
                
                mergedDict[key] = extraValue
                logger.warning("ModelWithExtras.encode: Extra '\(key)' added successfully to merged dict")
            } catch {
                logger.warning("ModelWithExtras.encode: Failed to encode extra '\(key)': \(error)")
                // Fallback: try to use the value directly if it's a basic type
                if let string = value as? String {
                    mergedDict[key] = string
                    logger.warning("ModelWithExtras.encode: Used string value directly for '\(key)'")
                } else if let int = value as? Int {
                    mergedDict[key] = int
                    logger.warning("ModelWithExtras.encode: Used int value directly for '\(key)'")
                } else {
                    logger.warning("ModelWithExtras.encode: Could not add extra '\(key)'")
                }
            }
        }
        
        logger.warning("ModelWithExtras.encode: Final merged dict has \(mergedDict.count) properties")
        
        // Step 4: Pretty print the merged structure
        if let finalData = try? JSONSerialization.data(withJSONObject: mergedDict, options: .prettyPrinted),
           let finalJSON = String(data: finalData, encoding: .utf8) {
            logger.warning("ModelWithExtras.encode: Merged structure:\n\(finalJSON)")
        }
        
        // Step 5: Encode merged dictionary
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in mergedDict {
            try encodeAny(value, forKey: key, in: &container)
        }
        
        logger.warning("ModelWithExtras.encode: Encoding completed")
    }
    
    // Helper to encode Any values
    private func encodeAny(_ value: Any, forKey key: String, in container: inout KeyedEncodingContainer<StringCodingKey>) throws {
        let codingKey = StringCodingKey(key)
        
        if let string = value as? String {
            try container.encode(string, forKey: codingKey)
        } else if let int = value as? Int {
            try container.encode(int, forKey: codingKey)
        } else if let double = value as? Double {
            try container.encode(double, forKey: codingKey)
        } else if let bool = value as? Bool {
            try container.encode(bool, forKey: codingKey)
        } else if let array = value as? [Any] {
            // For arrays, we'd need more complex handling
            try container.encode(String(describing: array), forKey: codingKey)
        } else if let dict = value as? [String: Any] {
            // For nested objects, we'd need more complex handling
            try container.encode(String(describing: dict), forKey: codingKey)
        } else if value is NSNull {
            try container.encodeNil(forKey: codingKey)
        } else {
            try container.encode(String(describing: value), forKey: codingKey)
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
        let logger = Logger(label: "Mist")
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        logger.warning("ModelContainer.encode: Starting encoding for \(models.count) models")
        
        for (key, model) in models.sorted(by: { $0.key < $1.key }) {
            logger.warning("ModelContainer.encode: ═══════════════════════════════════")
            logger.warning("ModelContainer.encode: Processing model key: '\(key)'")
            logger.warning("ModelContainer.encode: Model type: \(type(of: model))")
            
            // Get extras from the model
            let extras = model.contextExtras()
            logger.warning("ModelContainer.encode: Context extras count: \(extras.count)")
            if !extras.isEmpty {
                logger.warning("ModelContainer.encode: Extra keys: [\(extras.keys.sorted().joined(separator: ", "))]")
                for (extraKey, extraValue) in extras.sorted(by: { $0.key < $1.key }) {
                    logger.warning("ModelContainer.encode:   - \(extraKey): \(extraValue)")
                }
            }
            
            // Wrap model with its extras and encode
            let wrapper = ModelWithExtras(model: model, extras: extras)
            try container.encode(wrapper, forKey: StringCodingKey(key))
            
            // Capture final combined structure
            let testEncoder = JSONEncoder()
            testEncoder.outputFormatting = .prettyPrinted
            if let finalData = try? testEncoder.encode(wrapper),
               let finalJSON = String(data: finalData, encoding: .utf8) {
                logger.warning("ModelContainer.encode: Final combined JSON for '\(key)':\n\(finalJSON)")
            }
            
            logger.warning("ModelContainer.encode: Model '\(key)' encoding complete ✓")
        }
        
        logger.warning("ModelContainer.encode: ═══════════════════════════════════")
        logger.warning("ModelContainer.encode: All models encoded successfully")
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

