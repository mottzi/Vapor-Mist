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

        guard let leafRenderer = renderer as? LeafRenderer else { return nil }

        // Use the component's name as the template identifier (matches production behavior)
        let templateName = self.name
        let templateContent = templateStringLiteral(id: id)

        guard let html = try? await renderWithInMemoryTemplate(
            templateName: templateName,
            templateContent: templateContent,
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

/// Renders an in-memory template using the real production `LeafRenderer`
///
/// This function uses Vapor's actual rendering pipeline, ensuring:
/// - Full Leaf tag support (including custom tags)
/// - Consistent behavior with file-based templates
/// - Same event loop and configuration as production
/// - No manual parsing or serialization
///
/// - Parameters:
///   - templateName: Unique name for this template (e.g., "inline-UUID")
///   - templateContent: The Leaf template string
///   - context: The Encodable context to pass to the template
///   - renderer: The LeafRenderer from the Vapor app
/// - Returns: The rendered HTML string
func renderWithInMemoryTemplate<E: Encodable>(
    templateName: String,
    templateContent: String,
    context: E,
    using renderer: LeafRenderer
) async throws -> String {

    // Create an in-memory source with our template
    let memorySource = MemoryLeafSource(templates: [templateName: templateContent])

    // Create a new renderer with the same configuration but using our in-memory source
    // Use LeafSources.singleSource() to wrap our custom source
    let inlineRenderer = LeafRenderer(
        configuration: renderer.configuration,
        sources: .singleSource(memorySource),
        eventLoop: renderer.eventLoop
    )

    // Use the REAL LeafRenderer.render() method - same as production!
    let view = try await inlineRenderer.render(templateName, context).get()

    // Convert the rendered view to a string
    return String(buffer: view.data)

}

/// A `LeafSource` implementation that stores templates in memory for testing
struct MemoryLeafSource: LeafSource {
    
    private let templates: [String: String]
    
    init(templates: [String: String]) {
        self.templates = templates
    }
    
    func file(template: String, escape: Bool, on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        guard let content = templates[template] else {
            return eventLoop.makeFailedFuture(LeafError(.noTemplateExists(template)))
        }
        let buffer = ByteBuffer(string: content)
        return eventLoop.makeSucceededFuture(buffer)
    }
    
}
#endif
