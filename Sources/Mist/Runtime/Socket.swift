import Vapor
import Leaf

public struct Socket {
    
    /// Opens the websocket endpoint and upgrades connecting clients.
    static func register(with app: Application) {
        
        let router = switch app.mist.socket.middleware {
            case .none: app
            case .some(let middleware): app.grouped(middleware)
        }

        router.webSocket(app.mist.socket.path, shouldUpgrade: app.mist.socket.shouldUpgrade) { request, socket async in
            await Connection(over: socket, on: request.application).onUpgrade()
        }
    }
}

extension Socket.Connection {
    
    /// Registers the connected client with the runtime and starts listening to incoming messages.
    func onUpgrade() async {
        
        await app.mist.clients.addClient(clientID: clientID, socket: socket)
        await app.mist.clients.send("Client (\(clientID.short)) was registered.", to: clientID)
        
        socket.onText { ws, text async in
            await onText(text)
        }
        
        socket.onClose.whenComplete { _ in
            Task.detached { await app.mist.clients.removeClient(clientID: clientID) }
        }
    }
    
    /// Decodes an incoming message and routes it to the matching runtime handler.
    func onText(_ text: String) async {
        
        guard let data = text.data(using: .utf8) else { return }
        guard let message = try? JSONDecoder().decode(Message.self, from: data) else { return }
        
        switch message {
            case .subscribe(let component):
                await handleSubscription(of: component)
            
            case .action(let component, let targetID, let action):
                await handleAction(action, of: component, on: targetID)
            
            default: break
        }
    }
    
}

extension Socket.Connection {

    /// Registers a client's component subscription with the runtime. Sends the current fragment when available.
    func handleSubscription(of component: String) async {
        
        let success = await app.mist.clients.addSubscription(component, to: clientID)
        let response = success
            ? "Client (\(clientID.short)) subscribed to component '\(component)'."
            : "Client (\(clientID.short)) didn't subscribe to component '\(component)'."
        await app.mist.clients.send(response, to: clientID)
        
        if success, let fragment = await app.mist.components.getComponent(named: component) as? any FragmentComponent {
            await fragment.sendCurrent(to: clientID, app: app)
        }
    }

    /// Performs a component action and sends any resulting updates back to the client.
    func handleAction(_ action: String, of component: String, on targetID: UUID?) async {
        
        let result = await app.mist.components.performAction(action, of: component, on: targetID, for: clientID)

        if case .success = result {
            let componentInstance = await app.mist.components.getComponent(named: component)

            if let modelID = targetID, let instanceComponent = componentInstance as? any InstanceComponent {
                let state = await app.mist.clients.getState(for: clientID, componentID: modelID.uuidString, default: instanceComponent.defaultState)
                if let html = await instanceComponent.render(with: modelID, state: state, on: app.db, using: app.leaf.renderer) {
                    await app.mist.clients.send(Message.InstanceUpdate(component: component, modelID: modelID, html: html), to: clientID)
                }
            }

            if let fragment = componentInstance as? any PollingComponent {
                guard !app.didShutdown else { return }
                
                guard let context = await fragment.poll(on: app.db) else {
                    await app.mist.clients.broadcast(Message.QueryDelete(component: component))
                    return
                }
                
                guard let html = await fragment.render(with: context, using: app.leaf.renderer) else { return }
                await app.mist.clients.broadcast(Message.QueryUpdate(component: component, html: html))
            }
        }

        let resultMessage = switch result {
            case .success(let message): message ?? "Success"
            case .failure(let message): message ?? "Failure"
        }

        let message = Message.ActionResultMessage(component: component, targetID: targetID, action: action, result: result, message: resultMessage)
        await app.mist.clients.send(message, to: clientID)
    }

}

extension Socket {
    
    struct Connection {
        
        let app: Application
        let socket: WebSocket
        let clientID: UUID

        @discardableResult
        init(over socket: WebSocket, on app: Application,) {
            self.app = app
            self.socket = socket
            self.clientID = UUID()
        }
    }
    
}

extension UUID {
    
    var short: String { String(uuidString.prefix(8)) }
    
}
