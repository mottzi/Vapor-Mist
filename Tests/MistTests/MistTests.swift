import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import Mist
@testable import LeafKit

#if DEBUG
protocol TestableComponent: Mist.Component {
    
    func templateStringLiteral(id: UUID) -> String
    
}

extension TestableComponent {
    
    func render(id: UUID, on db: Database, using renderer: ViewRenderer) async -> String? {
        
        guard let context = await makeContext(of: id, in: db) else { return nil }
        
        guard let html = try? renderLeafForTesting(templateStringLiteral(id: id), with: context) else { return nil }
        
        return html
    }
    
}

extension Mist.Components {
    
    func registerWOListenerForTesting(_ component: any Mist.Component) {
        guard components.contains(where: { $0.name == component.name }) == false else { return }
        components.append(component)
        
        // Populate reverse index for O(1) model-to-component lookup
        for model in component.models {
            let key = ObjectIdentifier(model)
            modelToComponents[key, default: []].append(component)
        }
    }
    
    func getStorgeForTesting() async -> [any Mist.Component] {
        return components
    }
    
    func resetForTesting() async {
        components = []
        modelToComponents = [:]
    }
    
}

extension Clients {
    
    func getClients() -> [Client] {
        return clients
    }
    
    func resetForTesting() async {
        clients = []
    }
    
}

// enables leaf rendering with in-memory template string literal
func renderLeafForTesting<E: Encodable>(_ templateString: String, with context: E) throws -> String {
    
    // 1. Convert Encodable context to LeafData
    let contextData = try JSONEncoder().encode(context)
    let dict = try JSONSerialization.jsonObject(with: contextData) as? [String: Any] ?? [:]
    let leafContext = convertDictionaryToLeafData(dict)
    
    // 2. Set up LeafKit components for direct rendering
    var lexer = LeafLexer(name: "inline-template", template: templateString)
    let tokens = try lexer.lex()
    
    var parser = LeafParser(name: "inline-template", tokens: tokens)
    let ast = try parser.parse()
    
    var serializer = LeafSerializer(ast: ast, ignoreUnfoundImports: false)
    
    // 3. Perform the serialization
    let buffer = try serializer.serialize(context: leafContext)
    
    // 4. Convert ByteBuffer to String
    return buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) ?? ""
}

// recursively converts a dictionary with Any values to a dictionary with LeafData values
func convertDictionaryToLeafData(_ dictionary: [String: Any]) -> [String: LeafData] {
    
    var result = [String: LeafData]()
    
    for (key, value) in dictionary {
        result[key] = convertToLeafData(value)
    }
    
    return result
}

// Converts a single value to LeafData
func convertToLeafData(_ value: Any) -> LeafData {
    
    switch value {
        case let string as String: return .string(string)
        case let int as Int: return .int(int)
        case let double as Double: return .double(double)
        case let bool as Bool: return .bool(bool)
        case let array as [Any]: return .array(array.map { convertToLeafData($0) })
        case let dict as [String: Any]: return .dictionary(convertDictionaryToLeafData(dict))
        case let date as Date: return .double(date.timeIntervalSince1970)
        case let uuid as UUID: return .string(uuid.uuidString)
        case let data as Data: return .data(data)
        case is NSNull: return .nil(.string)
        default: return .nil(.string)
    }
}
#endif
