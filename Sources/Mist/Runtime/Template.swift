import Vapor
import LeafKit
import NIOCore

/// Template source used when rendering a component.
public enum Template: Sendable {
    
    /// A file-backed template.
    case file(path: String)
    
    /// An inline template string.
    case inline(template: String)
    
}

extension MistInterface {
    
    /// Registers inline templates with Leaf, using the name of the component. Preserves the default file-backed source.
    func registerTemplates(for components: [any Component]) async throws {
        
        let sources = LeafSources()
        let templates = TemplateSource()
        
        for component in components {
            guard case .inline(let template) = component.template else { continue }
            await templates.register(name: component.name, template: template)
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

/// Leaf source used by the runtime to register inline templates for component rendering.
actor TemplateSource: LeafSource {
    
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
