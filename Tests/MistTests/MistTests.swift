import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
import LeafKit
@testable import Mist

#if DEBUG
extension Mist.Components
{
    func registerWOListenerForTesting(_ component: any Mist.InstanceComponent)
    {
        guard componentsByName[component.name] == nil else { return }
        componentsByName[component.name] = component

        for model in component.models {
            let key = ObjectIdentifier(model)
            modelToInstanceComponents[key, default: []].append(component)
        }
    }
}

func registerAndRenderTemplate<E: Encodable>(
    name: String,
    content: String,
    context: E,
    using renderer: LeafRenderer
) async throws -> String {

    // Create an in-memory template source (just like production TemplateSource)
    let templateSource = LeafTemplateSource()
    await templateSource.register(name: name, template: content)

    // Get the renderer's existing sources
    let sources = renderer.sources

    // Register our template source with a unique test key
    let sourceKey = "test-templates-\(UUID().uuidString)"
    try? sources.register(source: sourceKey, using: templateSource, searchable: true)

    // Render using the real renderer with the registered source
    let view = try await renderer.render(name, context).get()

    // Convert the rendered view to a string
    return String(buffer: view.data)

}
#endif
