import Vapor
import Fluent

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
fileprivate struct EncodableWithExtras: Encodable {

    let base: any Encodable
    let extras: [String: any Encodable]

    func encode(to encoder: Encoder) throws {
        // 1) encode base model into same encoder (this writes stored fields)
        try base.encode(to: encoder)

        // 2) then encode extras into same nested encoder under string keys
        if !extras.isEmpty {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            for (k, v) in extras {
                try container.encode(v, forKey: StringCodingKey(k))
            }
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
        
        for (key, value) in models {
            // Get extras from the model via protocol method
            let extras = value.contextExtras()
            
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

