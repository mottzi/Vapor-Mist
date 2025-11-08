import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(MistMacros)
import MistMacros

final class ExtraContextProviderMacroTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "ExtraContextProvider": ExtraContextProviderMacro.self,
    ]
    
    func testMacroWithSingleExtraProperty() throws {
        assertMacroExpansion(
            """
            @ExtraContextProvider
            struct User {
                var name: String
                
                @ExtraContext var displayName: String {
                    name.uppercased()
                }
            }
            """,
            expandedSource: """
            struct User {
                var name: String
                
                @ExtraContext var displayName: String {
                    name.uppercased()
                }
            
                func contextExtras() -> [String: any Encodable] {
                    var extras: [String: any Encodable] = [:]
                    extras["displayName"] = displayName
                    return extras
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacroWithMultipleExtraProperties() throws {
        assertMacroExpansion(
            """
            @ExtraContextProvider
            final class Article {
                var title: String
                var views: Int
                
                @ExtraContext var titleUpper: String {
                    title.uppercased()
                }
                
                @ExtraContext var isPopular: Bool {
                    views > 1000
                }
            }
            """,
            expandedSource: """
            final class Article {
                var title: String
                var views: Int
                
                @ExtraContext var titleUpper: String {
                    title.uppercased()
                }
                
                @ExtraContext var isPopular: Bool {
                    views > 1000
                }
            
                func contextExtras() -> [String: any Encodable] {
                    var extras: [String: any Encodable] = [:]
                    extras["titleUpper"] = titleUpper
                    extras["isPopular"] = isPopular
                    return extras
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacroWithNoExtraProperties() throws {
        assertMacroExpansion(
            """
            @ExtraContextProvider
            struct Simple {
                var name: String
                var count: Int
            }
            """,
            expandedSource: """
            struct Simple {
                var name: String
                var count: Int
            
                func contextExtras() -> [String: any Encodable] {
                    var extras: [String: any Encodable] = [:]
            
                    return extras
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacroIgnoresNonExtraContextProperties() throws {
        assertMacroExpansion(
            """
            @ExtraContextProvider
            struct Mixed {
                var regular: String
                
                @ExtraContext var extra: String {
                    "computed"
                }
                
                var anotherRegular: Int
            }
            """,
            expandedSource: """
            struct Mixed {
                var regular: String
                
                @ExtraContext var extra: String {
                    "computed"
                }
                
                var anotherRegular: Int
            
                func contextExtras() -> [String: any Encodable] {
                    var extras: [String: any Encodable] = [:]
                    extras["extra"] = extra
                    return extras
                }
            }
            """,
            macros: testMacros
        )
    }

}
#endif

