import Foundation

public enum StateValue: Codable, Sendable, Equatable
{
    case bool(Bool)
    case string(String)
    case int(Int)
    
    public var bool: Bool?
    {
        if case .bool(let value) = self { return value }
        return nil
    }
    
    public var string: String?
    {
        if case .string(let value) = self { return value }
        return nil
    }
    
    public var int: Int?
    {
        if case .int(let value) = self { return value }
        return nil
    }
    
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.singleValueContainer()
        switch self
        {
            case .bool(let value): try container.encode(value)
            case .string(let value): try container.encode(value)
            case .int(let value): try container.encode(value)
        }
    }
    
    public init(from decoder: Decoder) throws
    {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self)
        {
            self = .bool(boolValue)
            return
        }
        if let intValue = try? container.decode(Int.self)
        {
            self = .int(intValue)
            return
        }
        if let stringValue = try? container.decode(String.self)
        {
            self = .string(stringValue)
            return
        }
        throw DecodingError.valueNotFound(
            StateValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported state value type")
        )
    }
}

public typealias MistState = [String: StateValue]

