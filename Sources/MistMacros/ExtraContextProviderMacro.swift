import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct ExtraContextProviderMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Only work on classes and structs
        guard declaration.is(ClassDeclSyntax.self) || declaration.is(StructDeclSyntax.self) else {
            throw MacroError.notApplicable
        }
        
        // Find all properties marked with @ExtraContext
        let members = declaration.memberBlock.members
        var extraProperties: [String] = []
        
        for member in members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            
            // Check if this property has @ExtraContext attribute
            let hasExtraContext = varDecl.attributes.contains { attribute in
                guard case let .attribute(attr) = attribute,
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self) else {
                    return false
                }
                return identifier.name.text == "ExtraContext"
            }
            
            guard hasExtraContext else { continue }
            
            // Extract property name(s)
            for binding in varDecl.bindings {
                if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                    let propertyName = pattern.identifier.text
                    extraProperties.append(propertyName)
                }
            }
        }
        
        // Generate the contextExtras() method
        let extrasDict = extraProperties.map { propertyName in
            "            extras[\"\(propertyName)\"] = \(propertyName)"
        }.joined(separator: "\n")
        
        let methodDecl: DeclSyntax = """
        func contextExtras() -> [String: any Encodable] {
            var extras: [String: any Encodable] = [:]
        \(raw: extrasDict)
            return extras
        }
        """
        
        return [methodDecl]
    }

}

enum MacroError: Error, CustomStringConvertible {

    case notApplicable
    
    var description: String {
        switch self {
        case .notApplicable:
            return "@ExtraContextProvider can only be applied to classes or structs"
        }
    }

}

