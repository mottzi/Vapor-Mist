import Vapor

/// A unit addressed and updated as a single fragment.
public protocol FragmentComponent: Component {
    
    /// Whether actions temporarily suppress automatic fragment refresh.
    var pausesDuringAction: Bool { get }
    
    /// Renders the fragment as it currently exists.
    func renderCurrent(app: Application) async -> RenderResult
    
}

public extension FragmentComponent {
    
    /// Default: actions do not suppress automatic fragment refresh.
    var pausesDuringAction: Bool { false }
    
}

extension FragmentComponent {
    
    /// Sends the fragment's current HTML to one client.
    func sendCurrent(to clientID: UUID, app: Application) async {
        
        switch await renderCurrent(app: app) {
            case .rendered(let html):
                await app.mist.clients.send(Message.QueryUpdate(component: name, html: html), to: clientID)
            case .absent:
                await app.mist.clients.send(Message.QueryDelete(component: name), to: clientID)
            case .failed:
                break
        }
    }

    /// Broadcasts the fragment's current HTML to all subscribers.
    func broadcastCurrent(app: Application) async {
        
        switch await renderCurrent(app: app) {
            case .rendered(let html):
                await app.mist.clients.broadcast(Message.QueryUpdate(component: name, html: html))
            case .absent:
                await app.mist.clients.broadcast(Message.QueryDelete(component: name))
            case .failed:
                break
        }
    }

}
