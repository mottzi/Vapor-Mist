import Fluent
import Leaf
import LeafKit
import Vapor

public struct Socket
{
    func register(on app: Application)
    {
        let router = switch app.mist.socketMiddleware {
            case .none: app
            case .some(let middleware): app.grouped(middleware)
        }

        router.webSocket(app.mist.socketPath, shouldUpgrade: app.mist.shouldUpgrade)
        { request, ws async in
            await Connection(app: request.application, ws: ws).onUpgrade()
        }
    }
}

extension Socket.Connection
{
    func onUpgrade() async
    {
        await app.mist.clients.addClient(id: clientID, socket: ws)
        await app.mist.clients.send("Client (\(clientID.short)) was registered.", to: clientID)

        ws.onText
        { ws, text async in
            await onText(text)
        }

        ws.onClose.whenComplete
        { _ in
            Task.detached { await app.mist.clients.removeClient(id: clientID) }
        }
    }

    func onText(_ text: String) async
    {
        guard let data = text.data(using: .utf8) else { return }
        guard let message = try? JSONDecoder().decode(Message.self, from: data) else { return }

        switch message
        {
            case .subscribe(let component): await handleSubscribe(component)
            case .action(let component, let id, let action): await handleAction(component, id, action)
            default: break
        }
    }

    func handleSubscribe(_ component: String) async
    {
        let success = await app.mist.clients.addSubscription(component, to: clientID)
        let response = success
            ? "Client (\(clientID.short)) subscribed to component '\(component)'."
            : "Client (\(clientID.short)) didn't subscribe to component '\(component)'."
        await app.mist.clients.send(response, to: clientID)
    }

    func handleAction(_ component: String, _ id: UUID?, _ action: String) async
    {
        let result = await app.mist.components.performAction(component: component, action: action, id: id, clientID: clientID, clients: app.mist.clients, on: app.db)

        if case .success = result, let id
        {
            if let componentInstance = await app.mist.components.getComponent(usingName: component) as? any InstanceComponent
            {
                let state = await app.mist.clients.state(for: clientID, componentID: id.uuidString, default: componentInstance.defaultState)
                if let html = await componentInstance.render(id: id, state: state, on: app.db, using: app.leaf.renderer)
                {
                    await app.mist.clients.send(Message.InstanceUpdate(component: component, id: id, html: html), to: clientID)
                }
            }
        }

        let resultMessage = switch result
        {
            case .success(let message): message ?? "Success"
            case .failure(let message): message ?? "Failure"
        }

        let message = Message.ActionResult(component: component, id: id, action: action, result: result, message: resultMessage)
        await app.mist.clients.send(message, to: clientID)
    }

}

extension Socket
{
    struct Connection
    {
        let app: Application
        let ws: WebSocket
        let clientID: UUID

        @discardableResult
        init(app: Application, ws: WebSocket)
        {
            self.app = app
            self.ws = ws
            self.clientID = UUID()
        }
    }
}

extension UUID
{
    var short: String { String(uuidString.prefix(8)) }
}
