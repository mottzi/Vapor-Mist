import Vapor

extension Application {

    /// Main access point in Vapor applications.
    public var mist: MistInterface { MistInterface(app: self) }

    /// Resolves a registered fragment component by type for server-side rendering.
    public func mistComponent<C: FragmentComponent>(_ type: C.Type) async -> C? {
        await mist.components.getComponent(named: String(describing: type)) as? C
    }

}

public struct MistInterface {

    let app: Application

    /// Accesses the runtime client registry.
    public var clients: Clients { _clients }

    /// Accesses the runtime component registry.
    public var components: Components { _components }

    /// Accesses append-only runtime streams.
    public var streams: Streams { _streams }

    /// User-configurable socket configuration used for endpoint registration.
    public var socket: MistSocketConfiguration { _socket }

    /// Prepares the Mist runtime. Registers components, their templates, and the websocket endpoint.
    public func use(@ComponentBuilder _ components: @Sendable () -> [any Component]) async throws {

        let components = components()
        try await prepareLeafTemplates(for: components)
        await app.mist.components.registerComponents(components)
        registerSocketIfNeeded()
    }

}
