import Vapor
import Fluent

struct MergingEncoder: Encodable
{
    private static let jsonEncoder = JSONEncoder()
    
    let base: any Encodable
    let extras: [String: any Encodable]

    let logger = Logger(label: "Mist.MergedModelContainer")

    func encode(to encoder: Encoder) throws
    {
        let json = try Self.jsonEncoder.encode(base)
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
            logger.warning("🔄 Processing extra '\(key)' (type: \(type(of: value)))")
            
            switch value 
            {
                case is String: encodePrimitive(key: key, value: value, into: &dict)
                case is Int: encodePrimitive(key: key, value: value, into: &dict)
                case is Double: encodePrimitive(key: key, value: value, into: &dict)
                case is Bool: encodePrimitive(key: key, value: value, into: &dict)
                default: encodeOther(key: key, value: value, into: &dict)
            }
        }
        
        logger.warning("📋 Final properties: \(dict.keys.sorted())")

        // encode dictionary back to parent encoder
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in dict {
            try container.encode(AnyEncodable(value), forKey: StringCodingKey(key))
        }
    }

    func encodePrimitive(key: String, value: Any, into dict: inout [String: Any])
    {
        dict[key] = value
        logger.warning("➕ Added primitive extra '\(key)': \(value)")
    }

    func encodeOther(key: String, value: Any, into dict: inout [String: Any])
    {
        guard let extraData = try? Self.jsonEncoder.encode(AnyEncodable(value)),
              let decodedExtra = try? JSONSerialization.jsonObject(with: extraData, options: [.allowFragments])
        else { return logger.warning("⚠️ Skipping complex extra '\(key)' - failed to encode") }
        dict[key] = decodedExtra
        logger.warning("➕ Added complex extra '\(key)': \(decodedExtra)")
    }
}

struct AnyEncodable: Encodable
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

struct StringCodingKey: CodingKey
{
    public var stringValue: String
    public var intValue: Int?
    
    public init(_ string: String)
    {
        self.stringValue = string
        self.intValue = nil
    }
    
    public init?(stringValue: String)
    {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    public init?(intValue: Int)
    {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}


