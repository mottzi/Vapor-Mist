import Vapor
import Fluent

public struct TypedContext<C: ModelComponent>: Sendable {
    public let raw: ComponentContext
    
    public init(raw: ComponentContext) {
        self.raw = raw
    }
    
    public var state: ComponentState { raw.state }
    
    public func model<M: Model>(_ type: M.Type) -> M? { raw.model(type) }
}

/// KeyPath subscripts for QueryComponent.
public extension TypedContext where C: QueryComponent {
    subscript<T>(keyPath: KeyPath<C.FragmentModel, T>) -> T? { raw[keyPath] }
    subscript<T>(keyPath: KeyPath<C.FragmentModel, T?>) -> T? { raw[keyPath] }
}

/// KeyPath subscripts for InstanceComponent based on tuple arity.

public extension TypedContext where C: InstanceComponent {
    subscript<M1: Model, T>(keyPath: KeyPath<M1, T>) -> T? where C.Models == M1.Type { raw[keyPath] }
    subscript<M1: Model, T>(keyPath: KeyPath<M1, T?>) -> T? where C.Models == M1.Type { raw[keyPath] }
}

public extension TypedContext where C: InstanceComponent {
    subscript<M1: Model, M2: Model, T>(keyPath: KeyPath<M1, T>) -> T? where C.Models == (M1.Type, M2.Type) { raw[keyPath] }
    subscript<M1: Model, M2: Model, T>(keyPath: KeyPath<M1, T?>) -> T? where C.Models == (M1.Type, M2.Type) { raw[keyPath] }
    
    subscript<M1: Model, M2: Model, T>(keyPath: KeyPath<M2, T>) -> T? where C.Models == (M1.Type, M2.Type) { raw[keyPath] }
    subscript<M1: Model, M2: Model, T>(keyPath: KeyPath<M2, T?>) -> T? where C.Models == (M1.Type, M2.Type) { raw[keyPath] }
}

public extension TypedContext where C: InstanceComponent {
    subscript<M1: Model, M2: Model, M3: Model, T>(keyPath: KeyPath<M1, T>) -> T? where C.Models == (M1.Type, M2.Type, M3.Type) { raw[keyPath] }
    subscript<M1: Model, M2: Model, M3: Model, T>(keyPath: KeyPath<M1, T?>) -> T? where C.Models == (M1.Type, M2.Type, M3.Type) { raw[keyPath] }
    
    subscript<M1: Model, M2: Model, M3: Model, T>(keyPath: KeyPath<M2, T>) -> T? where C.Models == (M1.Type, M2.Type, M3.Type) { raw[keyPath] }
    subscript<M1: Model, M2: Model, M3: Model, T>(keyPath: KeyPath<M2, T?>) -> T? where C.Models == (M1.Type, M2.Type, M3.Type) { raw[keyPath] }
    
    subscript<M1: Model, M2: Model, M3: Model, T>(keyPath: KeyPath<M3, T>) -> T? where C.Models == (M1.Type, M2.Type, M3.Type) { raw[keyPath] }
    subscript<M1: Model, M2: Model, M3: Model, T>(keyPath: KeyPath<M3, T?>) -> T? where C.Models == (M1.Type, M2.Type, M3.Type) { raw[keyPath] }
}
