import Vapor
import Fluent
import Leaf
import LeafKit

struct Socket {
    
    static func register(on app: Application) {
        
        app.webSocket("mist", "ws") { request, ws async in
            
            let app = request.application
            let clientID = UUID()
            await app.mist.clients.addClient(id: clientID, socket: ws)
            await app.mist.clients.send(Message.Text("Client connected and was added to registry."), to: clientID)
            
            ws.onText() { ws, text async in
                
                guard let data = text.data(using: .utf8) else { return }
                guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return }
                
                switch message
                {
                    case .subscribe(let component): 
                        await Self.handleSubscribeMessage(component: component, clientID: clientID, app: app)
                    case .action(let component, let id, let action): 
                        await Self.handleActionMessage(component: component, id: id, action: action, clientID: clientID, app: app)
                    default: break
                }
            }
            
            ws.onClose.whenComplete() { _ in
                Task { await app.mist.clients.removeClient(id: clientID) }
            }
        }
    }
    
    static func handleSubscribeMessage(component: String, clientID: UUID, app: Application) async {
        
        let success = await app.mist.clients.addSubscription(component, to: clientID)
        let response = success
            ? "Client subscribed to component '\(component)'."
            : "Client didn't subscribe to component '\(component)'."
        
        await app.mist.clients.send(Message.Text(response), to: clientID)
    }
    
    static func handleActionMessage(component: String, id: UUID, action: String, clientID: UUID, app: Application) async {
        
        let result = await app.mist.components.performAction(
            component: component,
            action: action,
            id: id,
            on: app.db
        )
        
        let resultMessage = switch result {
            case .success(let message): message ?? "Success"
            case .failure(let message): message ?? "Failure"
        }
        
        let message = Message.ActionResult(component: component, id: id, action: action, result: result, message: resultMessage)
        await app.mist.clients.send(message, to: clientID)
    }
    
}
