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
                    let success = await app.mist.clients.addSubscription(component, to: clientID)
                    let response = success
                    ? "Client subscribed to component '\(component)'."
                    : "Client didn't subscribe to component '\(component)'."
                    
                    await app.mist.clients.send(Message.Text(response), to: clientID)
                    
                case .action(let component, let id, let action):
                    do
                    {
                        _ = try await app.mist.components.executeAction(
                            component: component,
                            action: action,
                            id: id,
                            on: app.db
                        )
                    }
                    catch
                    {
                        app.logger.error("Action execution failed: \(error)")
                    }
                    
                default:
                    break
                }
            }
            
            ws.onClose.whenComplete() { _ in
                Task { await app.mist.clients.removeClient(id: clientID) }
            }
        }
    }
    
}
