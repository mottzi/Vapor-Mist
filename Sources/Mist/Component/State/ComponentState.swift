import Foundation

/// Constraints for data rendered by components or stored in shared fragment state.
public typealias ComponentData = Encodable & Equatable & Sendable

/// Per-client state keyed by component-defined field names.
public typealias ComponentState = [String: ComponentValue]

/// Primitive value stored inside per-client component state.
public enum ComponentValue: ComponentData {
    
    case bool(Bool)
    case string(String)
    case int(Int)
    
    public var bool: Bool?     { if case .bool(let value)   = self { value } else { nil } }
    public var int: Int?       { if case .int(let value)    = self { value } else { nil } }
    public var string: String? { if case .string(let value) = self { value } else { nil } }
    
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.singleValueContainer()
        
        if      let bool   = self.bool   { try container.encode(bool)   }
        else if let int    = self.int    { try container.encode(int)    }
        else if let string = self.string { try container.encode(string) }
    }
    
    public init(from decoder: Decoder) throws {
        
        let container = try decoder.singleValueContainer()
        
        if      let bool   = try? container.decode(Bool.self)   { self = .bool(bool)     }
        else if let int    = try? container.decode(Int.self)    { self = .int(int)       }
        else if let string = try? container.decode(String.self) { self = .string(string) }
        
        else { throw UnsupportedTypeError() }
    }
    
    private struct UnsupportedTypeError: Error {}
    
}
