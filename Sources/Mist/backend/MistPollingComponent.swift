import Vapor
import Fluent

public protocol PollingComponent: Component
{
    associatedtype PollContext: Encodable, Equatable

    var interval: Duration { get }

    func poll(on db: Database) async -> PollContext?
}

public extension PollingComponent
{
    var models: [any Mist.Model.Type] { [] }

    func render(context: PollContext, using renderer: ViewRenderer) async -> String?
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
        guard !app.didShutdown else { return }
        guard let context = await poll(on: app.db) else { return await app.mist.clients.broadcast(Message.QueryDelete(component: name)) }
        guard let html = await render(context: context, using: app.leaf.renderer) else { return }
        await app.mist.clients.broadcast(Message.QueryUpdate(component: name, html: html))
    }

    func startPolling(app: Application) async
    {
        var lastContext: PollContext? = nil

        func tick() async
        {
            guard !app.didShutdown && !Task.isCancelled else { return }
            
            guard let context = await poll(on: app.db) else
            {
                guard lastContext != nil else { return }
                lastContext = nil
                await app.mist.clients.broadcast(Message.QueryDelete(component: name))
                return
            }

            guard context != lastContext else { return }
            lastContext = context

            guard let html = await render(context: context, using: app.leaf.renderer) else { return }
            await app.mist.clients.broadcast(Message.QueryUpdate(component: name, html: html))
        }

        await tick()
        
        while !app.didShutdown && !Task.isCancelled
        {
            try? await Task.sleep(for: interval)
            guard !app.didShutdown && !Task.isCancelled else { break }
            await tick()
        }
    }
}
