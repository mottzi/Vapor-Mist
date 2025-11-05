import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
import Leaf
@testable import Mist
@testable import LeafKit

#if DEBUG
protocol TestableComponent: Mist.Component {

    func templateStringLiteral(id: UUID) -> String

}

extension TestableComponent {

    func render(id: UUID, on db: Database, using renderer: ViewRenderer) async -> String? {

        guard let context = await makeContext(of: id, in: db) else { return nil }

        // Register the template string with the renderer's sources (just like production)
        guard let leafRenderer = renderer as? LeafRenderer else { return nil }
        
        let templateName = self.name
        let templateContent = templateStringLiteral(id: id)
        
        guard let html = try? await registerAndRenderTemplate(
            name: templateName,
            content: templateContent,
            context: context,
            using: leafRenderer
        ) else { return nil }

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
    
    func resetForTesting() async {
        components = []
        modelToComponents = [:]
    }
    
}

extension Mist.Clients {
    
    func resetForTesting() async {
        clients = []
        componentToClients = [:]
    }
    
}

/// Registers a template string with the app's sources and renders it using the shared renderer
///
/// This mirrors the production approach used in `Mist.configure()`, ensuring:
/// - Same multi-source architecture (string source + file source fallback)
/// - Same caching behavior (templates cached after first parse)
/// - Same event loop and configuration
/// - Tests accurately reflect production behavior
///
/// - Parameters:
///   - name: Template identifier (e.g., component name)
///   - content: The Leaf template string
///   - context: The Encodable context to pass to the template
///   - renderer: The LeafRenderer from the Vapor app
/// - Returns: The rendered HTML string
func registerAndRenderTemplate<E: Encodable>(
    name: String,
    content: String,
    context: E,
    using renderer: LeafRenderer
) async throws -> String {

    // Create an in-memory string source (just like production MistStringSource)
    let stringSource = TestMemoryLeafSource()
    await stringSource.register(name: name, template: content)
    
    // Get the renderer's existing sources
    let sources = renderer.sources
    
    // Register our string source with a unique test key
    let sourceKey = "test-strings-\(UUID().uuidString)"
    try? sources.register(source: sourceKey, using: stringSource, searchable: true)
    
    // Render using the real renderer with the registered source
    let view = try await renderer.render(name, context).get()
    
    // Convert the rendered view to a string
    return String(buffer: view.data)

}

/// A `LeafSource` implementation that stores templates in memory for testing
///
/// This is an actor (like production `MistStringSource`) to ensure thread safety
/// and accurately mirror production behavior in tests.
actor TestMemoryLeafSource: LeafSource {
    
    private var templates: [String: String] = [:]
    
    init() {}
    
    func register(name: String, template: String) {
        self.templates[name] = template
    }
    
    nonisolated func file(template: String, escape: Bool, on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        
        let future = eventLoop.makeFutureWithTask {
            if let content = await self.templates[template] {
                var buffer = ByteBufferAllocator().buffer(capacity: content.utf8.count)
                buffer.writeString(content)
                return buffer
            } else {
                throw LeafError(.noTemplateExists(template))
            }
        }
        
        return future
    }
    
}
#endif
