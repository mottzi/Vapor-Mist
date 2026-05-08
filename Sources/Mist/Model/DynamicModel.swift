import Vapor
import Fluent

@dynamicMemberLookup
public struct DynamicModel: Sendable {
    public let model: any Model

    public var id: UUID? { model.id }

    public init(model: any Model) {
        self.model = model
    }

    public subscript<T>(dynamicMember member: String) -> T? {
        if let val = model.computedProperties[member] as? T { return val }
        
        let mirror = Mirror(reflecting: model)
        for child in mirror.children {
            let label = child.label?.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            if label == member {
                if let val = child.value as? T { return val }
                if let prop = child.value as? AnyProperty, let val = prop.anyValue as? T { return val }
            }
        }
        return nil
    }
}

@dynamicMemberLookup
public struct DynamicStateProxy: Sendable, Encodable {
    public let raw: ComponentState

    public init(raw: ComponentState) {
        self.raw = raw
    }

    public subscript(key: String) -> ComponentValue? {
        raw[key]
    }

    public subscript<T>(dynamicMember name: String) -> T? {
        let val = raw[name]
        switch val {
            case .string(let s): return s as? T
            case .int(let i): return i as? T
            case .bool(let b): return b as? T
            case .none: return nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        try raw.encode(to: encoder)
    }
}
