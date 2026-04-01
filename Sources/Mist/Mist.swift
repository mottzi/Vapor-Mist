import Vapor
import LeafKit

public extension Application {
    
    /// Main access point in Vapor applications.
    var mist: Mist { Mist(app: self) }
    
}

public struct Mist {
    
    let app: Application
    
    /// Accesses the runtime client registry.
    var clients: MistClients { _clients }
    
    /// Accesses the runtime component registry.
    var components: MistComponents { _components }
    
    /// User-configurable socket configuration used for endpoint registration.
    public var socket: MistSocketConfiguration { _socket }

    /// Prepares the Mist runtime. Registers components, their templates, and the websocket endpoint.
    public func use(@ComponentBuilder _ components: () -> [any MistComponent]) async throws {
        
        let components = components()
        try await app.mist.registerTemplates(for: components)
        await app.mist.components.registerComponents(components)
        MistSocket.register(with: app)
    }
    
}
