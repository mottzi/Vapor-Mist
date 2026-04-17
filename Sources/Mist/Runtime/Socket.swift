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
            Task { await app.mist.clients.removeClient(clientID: clientID) }
        }
    }
    
    /// Decodes an incoming message and routes it to the matching runtime handler.
    func onText(_ text: String) async {
        
        guard let data = text.data(using: .utf8) else { return }
        let message: Message
        do { message = try JSONDecoder().decode(Message.self, from: data) }
        catch { app.logger.warning("\(MistError.messageDecodeFailed(text, error))"); return }
        
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
        
        guard success else { return }
        await app.mist.components.sendCurrentSubscriptionState(for: component, to: clientID)
    }

    /// Performs a component action and sends any resulting updates back to the client.
    func handleAction(_ action: String, of component: String, on targetID: UUID?) async {
        
        let result = await app.mist.components.performAction(
            action,
            of: component,
            on: targetID,
            for: clientID
        )

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
