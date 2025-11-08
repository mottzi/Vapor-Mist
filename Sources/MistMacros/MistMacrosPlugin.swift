import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MistMacrosPlugin: CompilerPlugin {

    let providingMacros: [Macro.Type] = [
        ExtraContextProviderMacro.self,
        ExtraContextMacro.self,
    ]

}

