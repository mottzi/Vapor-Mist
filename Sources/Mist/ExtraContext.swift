import Foundation

/// Marks a computed property to be included in contextExtras()
///
/// Use this attribute on computed properties in models that have @ExtraContextProvider applied.
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
@attached(peer)
public macro ExtraContext() = #externalMacro(module: "MistMacros", type: "ExtraContextMacro")

