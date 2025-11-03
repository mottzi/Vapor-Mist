import Vapor
import Fluent
import Leaf
import LeafKit

struct Socket
{
    // registers websocket endpoint on vapor server
    static func register(on app: Application)
    {
        app.webSocket("mist", "ws")
        { request, ws async in
            
            // create new connection on upgrade
            let clientID = UUID()
            
            // add new connection to actor
            await Mist.Clients.shared.add(client: clientID, socket: ws)
            
            // send welcome message to client
            await Mist.Clients.shared.send(.text(message: "Client connected and added to registry."), to: clientID)
            
            // receive client message
            ws.onText()
            { ws, text async in
                
                // abort if message is not of type Mist.Message.subscribe
                guard let data = text.data(using: .utf8) else { return }
                guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return }
                guard case .subscribe(let component) = message else { return }
                        
                // add component subscription to client
                switch await Mist.Clients.shared.addSubscription(component, to: clientID)
                {
                    // send confirmation message
                    case true: await Mist.Clients.shared.send(.text(message: "Client subscribed to component '\(component)'."), to: clientID)
                    case false: await Mist.Clients.shared.send(.text(message: "Client didn't subscribe to component '\(component)'."), to: clientID)
                }
            }
            
            // remove connection from actor on close
            ws.onClose.whenComplete() { _ in Task { await Mist.Clients.shared.remove(client: clientID) } }
        }
    }
}
