import Foundation

/// Property wrapper for marking computed properties that should be included in contextExtras()
///
/// Use this wrapper on computed properties in models that have @ExtraContextProvider applied.
/// The macro will automatically collect these properties and include them in the generated
/// contextExtras() method.
///
/// Example:
/// ```swift
/// @ExtraContextProvider
/// final class User: Model {
///     @ID(key: .id) var id: UUID?
///     @Field(key: "name") var name: String
///     @Field(key: "created_at") var createdAt: Date
///
///     @ExtraContext var displayName: String {
///         name.capitalized
///     }
///
///     @ExtraContext var accountAge: Int {
///         Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
///     }
/// }
/// ```
@propertyWrapper
public struct ExtraContext<Value: Encodable> {

    private let computation: () -> Value
    
    public init(wrappedValue: @autoclosure @escaping () -> Value) {
        self.computation = wrappedValue
    }
    
    public var wrappedValue: Value {
        computation()
    }

}

