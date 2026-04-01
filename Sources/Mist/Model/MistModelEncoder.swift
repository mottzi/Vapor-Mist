import Vapor

/// Represents a model together with additional fields for encoding.
struct MistModelEncoder: Encodable {
    
    private static let jsonEncoder = JSONEncoder()
    
    let model: any MistModel
    let additionalFields: [String: any Encodable]
    
    init(model: any MistModel, adding additionalFields: [String : any Encodable]) {
        self.model = model
        self.additionalFields = additionalFields
    }

    /// Encodes the model object after merging in its additional fields.
    func encode(to encoder: Encoder) throws {
        
        let modelJSON = try Self.jsonEncoder.encode(model)
        guard var modelDict = try JSONSerialization.jsonObject(with: modelJSON) as? [String: Any]
        else { throw MistError.encoding("Model did not encode to JSON dictionary") }
        
        for (key, value) in additionalFields {
            switch value {
                case is String: addPrimitive(key: key, value: value, to: &modelDict)
                case is Int:    addPrimitive(key: key, value: value, to: &modelDict)
                case is Double: addPrimitive(key: key, value: value, to: &modelDict)
                case is Bool:   addPrimitive(key: key, value: value, to: &modelDict)
                
                default: addOther(key: key, value: value, to: &modelDict)
            }
        }
        
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        for (key, value) in modelDict {
            try container.encode(AnyEncodable(value), forKey: StringCodingKey(of: key))
        }
    }

    /// Adds a primitive field directly to the encoded model object.
    func addPrimitive(key: String, value: Any, to dict: inout [String: Any]) {
        dict[key] = value
    }

    /// Converts a non-primitive field through JSON before adding it to the encoded model object.
    func addOther(key: String, value: Any, to dict: inout [String: Any]) {
        guard let extraData = try? Self.jsonEncoder.encode(AnyEncodable(value)) else { return }
        guard let decodedExtra = try? JSONSerialization.jsonObject(with: extraData, options: [.allowFragments]) else { return }
        dict[key] = decodedExtra
    }
    
}

/// Encodes runtime values produced during model encoding.
struct AnyEncodable: Encodable {
    
    private let value: Any
    
    init(_ value: Any) {
        self.value = value
    }

    /// Encodes the wrapped value using the matching container shape for its runtime type.
    func encode(to encoder: Encoder) throws {
        
        switch value {
            case let value as String: try encodePrimitive(value, to: encoder)
            case let value as Bool:   try encodePrimitive(value, to: encoder)
            case let value as Int:    try encodePrimitive(value, to: encoder)
            case let value as Double: try encodePrimitive(value, to: encoder)
        
            case is NSNull:                  try encodeNil(to: encoder)
            case let value as [Any]:         try encodeArray(value, to: encoder)
            case let value as [String: Any]: try encodeDictionary(value, to: encoder)
            case let value as any Encodable: try value.encode(to: encoder)

            default: throw MistError.encoding("Unsupported value type: \(type(of: value))")
        }
    }
    
    private func encodePrimitive<T: Encodable>(_ value: T, to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    private func encodeNil(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }

    private func encodeArray(_ array: [Any], to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for item in array { try container.encode(AnyEncodable(item)) }
    }

    private func encodeDictionary(_ dict: [String: Any], to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in dict { try container.encode(AnyEncodable(value), forKey: StringCodingKey(of: key)) }
    }
    
}

/// Represents a coding key created from a runtime field name.
struct StringCodingKey: CodingKey {
    
    public var stringValue: String
    public var intValue: Int?
    
    public init(of string: String) {
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

enum MistError: Error { case encoding(String) }
