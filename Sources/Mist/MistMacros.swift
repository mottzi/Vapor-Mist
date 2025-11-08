/// Macro declarations for Mist's automatic context extras generation.
///
/// The @ExtraContextProvider macro inspects a type at compile time and generates
/// the contextExtras() method implementation by collecting all properties marked
/// with @ExtraContext.

/// Attaches to a type to automatically generate the contextExtras() method.
///
/// This macro scans the type for properties marked with @ExtraContext and generates
/// a contextExtras() implementation that includes all of them in the returned dictionary.
///
/// Example:
/// ```swift
/// @ExtraContextProvider
/// final class Article: Model {
///     @ID(key: .id) var id: UUID?
///     @Field(key: "title") var title: String
///     @Field(key: "views") var views: Int
///
///     @ExtraContext var titleUpper: String {
///         title.uppercased()
///     }
///
///     @ExtraContext var isPopular: Bool {
///         views > 1000
///     }
/// }
///
/// // Generated code:
/// // func contextExtras() -> [String: any Encodable] {
/// //     var extras: [String: any Encodable] = [:]
/// //     extras["titleUpper"] = titleUpper
/// //     extras["isPopular"] = isPopular
/// //     return extras
/// // }
/// ```
@attached(member, names: named(contextExtras))
public macro ExtraContextProvider() = #externalMacro(module: "MistMacros", type: "ExtraContextProviderMacro")

