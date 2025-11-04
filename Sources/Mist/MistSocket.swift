import Vapor
import Fluent
import Leaf
import LeafKit

struct Socket {

    static func register(on app: Application) {
        
        app.webSocket("mist", "ws") { request, ws async in
            
            let clientID = UUID()
            await Mist.Clients.shared.addClient(id: clientID, socket: ws)
            await Mist.Clients.shared.send(Message.Text("Client connected and was added to registry."), to: clientID)
            
            ws.onText() { ws, text async in
                
                guard let data = text.data(using: .utf8) else { return }
                guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return }
                guard case .subscribe(let component) = message else { return }

                let success = await Mist.Clients.shared.addSubscription(component, to: clientID)
                let response = success 
                    ? "Client subscribed to component '\(component)'." 
                    : "Client didn't subscribe to component '\(component)'."

                await Mist.Clients.shared.send(Message.Text(response), to: clientID)
            }
            
            ws.onClose.whenComplete() { _ in
                Task { await Mist.Clients.shared.removeClient(id: clientID) }
            }
        }
    }
    
}
