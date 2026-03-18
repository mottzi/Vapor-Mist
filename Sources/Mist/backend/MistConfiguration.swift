import LeafKit
import NIOCore
import Vapor

func configure(_ components: [any Component], on application: Application) async
{
    do {
        let inlineTemplates = TemplateSource()
        for component in components
        {
            guard case .inline(let template) = component.template else { continue }
            await inlineTemplates.register(name: component.name, template: template)
        }

        let sources = LeafSources()
        try sources.register(source: "mist-templates", using: inlineTemplates)
        try sources.register(source: "default", using: application.leaf.defaultSource)
        application.leaf.sources = sources

        await application.mist.components.registerComponents(components, with: application)

        let websocket = Socket()
        websocket.register(on: application)
    } catch {
        application.logger.warning("LeafSources throwed!: \n\(error.localizedDescription)")
    }
}

public actor TemplateSource: LeafSource
{
    private var templates: [String: String] = [:]

    public init() {}

    public func register(name: String, template: String)
    {
        self.templates[name] = template
    }

    public nonisolated func file(template: String, escape: Bool, on eventLoop: any EventLoop) throws -> EventLoopFuture<ByteBuffer>
    {
        return eventLoop.makeFutureWithTask
        {
            guard let content = await self.templates[template] else { throw LeafError(.noTemplateExists(template)) }
            var buffer = ByteBufferAllocator().buffer(capacity: content.utf8.count)
            buffer.writeString(content)
            return buffer
        }
    }

}

extension Application.Leaf
{
    var defaultSource: NIOLeafFiles
    {
        let root = configuration.rootDirectory
        application.logger.warning("Mist: computing defaultSource, rootDirectory='\(root)'")
        return NIOLeafFiles(
            fileio: application.fileio,
            limits: .default,
            sandboxDirectory: root,
            viewDirectory: root
        )
    }
}
