import Vapor
import Fluent

public protocol PollingComponent: Component
{
    var interval: Duration { get }

    func poll(on db: Database) async -> (any Encodable)?
}

public extension PollingComponent
{
    var models: [any Mist.Model.Type] { [] }

    func render(context: any Encodable, using renderer: ViewRenderer) async -> String?
    {
        let templateName = switch template
        {
            case .file(let path): path
            case .inline: name
        }

        guard let buffer = try? await renderer.render(templateName, context).data else { return nil }
        return String(buffer: buffer)
    }

    func handlePollingUpdate(app: Application) async
    {
        guard let context = await poll(on: app.db) else {
            return await app.mist.clients.broadcast(Message.QueryDelete(component: name))
        }

        guard let html = await render(context: context, using: app.leaf.renderer) else { return }
        await app.mist.clients.broadcast(Message.QueryUpdate(component: name, html: html))
    }

    func startPolling(app: Application) async
    {
        await handlePollingUpdate(app: app)

        while !app.didShutdown
        {
            try? await Task.sleep(for: interval)
            guard !app.didShutdown else { break }
            await handlePollingUpdate(app: app)
        }
    }
}
