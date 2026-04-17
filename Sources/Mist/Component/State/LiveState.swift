import Vapor

/// Actor that isolates context state for fragment components. Publishes updates to clients upon mutation.
/// Runtime installs render and broadcast hooks during registration.
public actor LiveState<State: ComponentData> {
    
    /// Current fragment state used for rendering and broadcasting updates.
    private var state: State
        
    /// Render hook used to turn current state into HTML.
    private var render: ((State) async -> String?)?
    
    /// Broadcast hook used to publish rendered HTML to subscribed clients.
    private var broadcast: ((String) async -> Void)?
    
    public init(of state: State) {
        self.state = state
    }
    
    /// Installs the fragment's render and broadcast hooks.
    /// Called during component registration before this state can publish updates.
    func boot(
        render: @escaping (State) async -> String?,
        broadcast: @escaping (String) async -> Void,
    ) {
        self.render = render
        self.broadcast = broadcast
    }
    
    /// Returns current state.
    public var current: State { state }
    
    /// Stores new state and broadcasts fresh HTML when the value actually changed.
    public func set(_ newState: State) async {
        
        guard let render, let broadcast else { return }
        guard newState != state else { return }
        
        state = newState
        let snapshot = state
        
        guard let html = await render(snapshot) else { return }
        guard state == snapshot else { return }
        await broadcast(html)
    }
    
}
