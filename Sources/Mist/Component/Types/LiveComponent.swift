import Vapor

/// A stateful fragment that renders and updates from periodically recomputed state.
public protocol LiveComponent: FragmentComponent {
    
    /// State type rendered by this fragment.
    associatedtype FragmentState: ComponentData
    
    /// Shared state rendered and synchronized for this fragment.
    var state: LiveState<FragmentState> { get }
    
    /// Interval between automatic refreshes.
    var refreshInterval: Duration { get }
    
    /// Refreshes fragment state for the current update cycle.
    func refresh(state: LiveState<FragmentState>, app: Application) async
    
}

public extension LiveComponent {
    
    /// Default: refresh every three seconds.
    var refreshInterval: Duration { .seconds(3) }
    
    /// Default: actions suppress automatic refresh while they run.
    var pausesDuringAction: Bool { true }
    
}

public extension LiveComponent {
    
    /// Renders the fragment from the current live state.
    func renderCurrent(app: Application) async -> String? {
        let current = await state.current
        return await render(with: current, using: app.leaf.renderer)
    }
    
}
