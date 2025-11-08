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
        
        // Log what we're about to encode
        logger.warning("ModelWithExtras.encode: Starting to encode model type: \(type(of: model))")
        logger.warning("ModelWithExtras.encode: Extras to add: \(extras.keys.sorted().joined(separator: ", "))")
        
        // Create a test JSON encoder to capture base model structure
        let testEncoder = JSONEncoder()
        testEncoder.outputFormatting = .prettyPrinted
        if let baseData = try? testEncoder.encode(model),
           let baseJSON = String(data: baseData, encoding: .utf8) {
            logger.warning("ModelWithExtras.encode: Base model JSON:\n\(baseJSON)")
        }
        
        // First encode the base model's properties
        try model.encode(to: encoder)
        logger.warning("ModelWithExtras.encode: Base model encoded")
        
        // Then encode extras into the same container
        if !extras.isEmpty {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            for (key, value) in extras.sorted(by: { $0.key < $1.key }) {
                logger.warning("ModelWithExtras.encode: Adding extra '\(key)' with value: \(value)")
                try container.encode(value, forKey: StringCodingKey(key))
                logger.warning("ModelWithExtras.encode: Extra '\(key)' successfully added")
            }
            logger.warning("ModelWithExtras.encode: All extras encoded")
        }
        
        logger.warning("ModelWithExtras.encode: Completed encoding")
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

