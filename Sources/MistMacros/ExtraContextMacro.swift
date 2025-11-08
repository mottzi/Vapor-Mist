import SwiftSyntax
import SwiftSyntaxMacros

/// A no-op peer macro that serves as a marker for properties
/// to be included in contextExtras()
public struct ExtraContextMacro: PeerMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This macro does nothing - it's just a marker for ExtraContextProviderMacro
        return []
    }

}

