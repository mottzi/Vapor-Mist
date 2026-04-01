import Vapor

/// A stateful fragment that renders and updates from manually updated state.
public protocol MistManualComponent: MistFragmentComponent {
    
    /// State type rendered by this fragment.
    associatedtype FragmentState: MistComponentData
    
    /// Shared state rendered and synchronized for this fragment.
    var state: MistLiveState<FragmentState> { get }
    
}

public extension MistManualComponent {
    
    /// Default: manual fragments use no per-client state.
    var defaultState: MistComponentState { [:] }
    
}

public extension MistManualComponent {
    
    /// Renders the fragment from the current state.
    func renderCurrent(app: Application) async -> String? {
        let current = await state.current
        return await render(with: current, using: app.leaf.renderer)
    }
    
}
