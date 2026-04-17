import Vapor

public extension Application {
    
    /// Main access point in Vapor applications.
    var mist: MistInterface { MistInterface(app: self) }
    
}

public struct MistInterface {
    
    let app: Application
    
    /// Accesses the runtime client registry.
    var clients: Clients { _clients }
    
    /// Accesses the runtime component registry.
    var components: Components { _components }
    
    /// User-configurable socket configuration used for endpoint registration.
    public var socket: MistSocketConfiguration { _socket }

    /// Prepares the Mist runtime. Registers components, their templates, and the websocket endpoint.
    public func use(@ComponentBuilder _ components: () -> [any Component]) async throws {
        
        let components = components()
        try await prepareLeafTemplates(for: components)
        await app.mist.components.registerComponents(components)
        registerSocketIfNeeded()
    }
    
}
