import Vapor
import LeafKit
import NIOCore

/// Leaf namespace used to create file-backed and inline templates.
public enum LeafTemplate {

    /// Creates a file-backed Leaf template.
    public static func file(_ path: String) -> any Template {
        LeafFileTemplate(path: path)
    }

    /// Creates an inline Leaf template string.
    public static func inline(_ source: String) -> any Template {
        LeafInlineTemplate(source: source)
    }

}

/// File-backed Leaf template implementation.
public struct LeafFileTemplate: Template {

    let path: String

    init(path: String) {
        self.path = path
    }

    public func render<Context: Encodable>(
        context: Context,
        componentName: String,
        using app: Application
    ) async throws -> String {
        let buffer = try await app.leaf.renderer.render(path, context).data
        return String(buffer: buffer)
    }

}

/// Inline Leaf template implementation.
public struct LeafInlineTemplate: Template {

    let source: String

    init(source: String) {
        self.source = source
    }

    public func render<Context: Encodable>(
        context: Context,
        componentName: String,
        using app: Application
    ) async throws -> String {
        let buffer = try await app.leaf.renderer.render(componentName, context).data
        return String(buffer: buffer)
    }

}

/// Leaf source used while registering inline templates during Mist startup.
actor LeafTemplateSource: LeafSource {

    private var templates: [String: String] = [:]

    public init() {}

    /// Stores an inline template under the component name used for rendering.
    public func register(name: String, template: String) {
        self.templates[name] = template
    }

    /// Resolves a registered inline template into a byte buffer for Leaf.
    public nonisolated func file(template: String, escape: Bool, on eventLoop: any EventLoop) throws -> EventLoopFuture<ByteBuffer> {

        eventLoop.makeFutureWithTask {
            guard let content = await self.templates[template] else { throw LeafError(.noTemplateExists(template)) }
            var buffer = ByteBufferAllocator().buffer(capacity: content.utf8.count)
            buffer.writeString(content)
            return buffer
        }
    }

}

extension MistInterface {

    /// Registers all inline Leaf templates and preserves the default file-backed Leaf source.
    func prepareLeafTemplates(for components: [any Component]) async throws {
        let sources = LeafSources()
        let templates = LeafTemplateSource()

        for component in components {
            guard let template = component.template as? LeafInlineTemplate else { continue }
            await templates.register(name: component.name, template: template.source)
        }

        let root = app.leaf.configuration.rootDirectory
        let defaultSource = NIOLeafFiles(
            fileio: app.fileio,
            limits: .default,
            sandboxDirectory: root,
            viewDirectory: root
        )

        try sources.register(source: "mist-templates", using: templates)
        try sources.register(source: "default", using: defaultSource)
        app.leaf.sources = sources
    }

}
