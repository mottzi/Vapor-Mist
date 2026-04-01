import Vapor

/// A stateful fragment that renders and updates from manually updated state.
public protocol ManualComponent: FragmentComponent {
    
    /// State type rendered by this fragment.
    associatedtype FragmentState: ComponentData
    
    /// Shared state rendered and synchronized for this fragment.
    var state: LiveState<FragmentState> { get }
    
}

public extension ManualComponent {
    
    /// Default: manual fragments use no per-client state.
    var defaultState: ComponentState { [:] }
    
}

public extension ManualComponent {
    
    /// Renders the fragment from the current state.
    func renderCurrent(app: Application) async -> String? {
        let current = await state.current
        return await render(with: current, using: app.leaf.renderer)
    }
    
}
