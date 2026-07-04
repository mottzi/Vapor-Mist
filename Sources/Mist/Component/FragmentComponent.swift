import Vapor

/// A unit addressed and updated as a single fragment.
public protocol FragmentComponent: Component {
    
    /// Whether actions temporarily suppress automatic fragment refresh.
    var pausesDuringAction: Bool { get }
    
    /// Renders the fragment as it currently exists.
    func renderCurrent(app: Application) async -> RenderResult

    /// Renders the fragment using per-client component state.
    func renderCurrent(app: Application, state: ComponentState) async -> RenderResult
    
}

public extension FragmentComponent {
    
    /// Default: actions do not suppress automatic fragment refresh.
    var pausesDuringAction: Bool { false }

    /// Default: fragments that do not opt into per-client state render as before.
    func renderCurrent(app: Application, state: ComponentState) async -> RenderResult {
        await renderCurrent(app: app)
    }

    /// Renders the fragment for server-side inlining before the socket takes over.
    func renderInitial(app: Application) async -> String? {
        switch await renderCurrent(app: app) {
            case .rendered(let html): return html
            case .absent, .failed: return nil
        }
    }
    
}
