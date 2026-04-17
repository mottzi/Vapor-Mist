import Vapor

/// A stateful fragment that renders and updates from periodically recomputed state.
public protocol LiveComponent: FragmentComponent {

    /// State type rendered by this fragment.
    associatedtype FragmentState: ComponentData

    /// HTML body type returned by Elementary-backed components. Defaults to `Never` for Leaf-backed components.
    associatedtype Body = Never

    /// Shared state rendered and synchronized for this fragment.
    var state: LiveState<FragmentState> { get }

    /// Interval between automatic refreshes.
    var refreshInterval: Duration { get }

    /// Refreshes fragment state for the current update cycle.
    func refresh(app: Application) async

    /// Returns the component's HTML body from current state. Implement for Elementary-backed rendering.
    func body(state: FragmentState) -> Body

}

public extension LiveComponent {

    /// Default: refresh every three seconds.
    var refreshInterval: Duration { .seconds(3) }

    /// Default: actions suppress automatic refresh while they run.
    var pausesDuringAction: Bool { true }

}

public extension LiveComponent where Body == Never {

    /// Leaf path: body is never called.
    func body(state: FragmentState) -> Never { fatalError() }

}

public extension LiveComponent {

    /// Renders the fragment from the current live state.
    func renderCurrent(app: Application) async -> RenderResult {
        let current = await state.current
        return await render(with: current, on: app)
    }

}
