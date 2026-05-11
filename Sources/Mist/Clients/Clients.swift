import Vapor

/// Runtime registry of connected clients, holding subscriptions and per-client component state.
public actor Clients {
    
    /// Connected clients registered with the runtime.
    var clients: [Client] = []

    /// Connected clients indexed by identifier for direct lookup.
    var clientsByID: [UUID: Client] = [:]
    
    /// Connected clients subscribed to each component.
    var componentToClients: [String: Set<UUID>] = [:]
    
    /// Per-client state keyed by component name or instance ID.
    var clientToComponentState: [UUID: [String: ComponentState]] = [:]
    
    /// Reference to the runtime components registry.
    let components: Components

    /// Logger for runtime diagnostics.
    let logger: Logger

    init(components: Components, logger: Logger) {
        self.components = components
        self.logger = logger
    }
    
}

extension Clients {
    
    /// The number of currently connected clients.
    public var count: Int { clients.count }
    
}
