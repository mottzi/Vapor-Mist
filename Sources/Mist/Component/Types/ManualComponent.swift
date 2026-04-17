import Vapor

/// A stateful fragment that renders and updates from manually updated state.
public protocol ManualComponent: FragmentComponent {

    /// State type rendered by this fragment.
    associatedtype FragmentState: ComponentData

    /// HTML body type returned by Elementary-backed components. Defaults to `Never` for Leaf-backed components.
    associatedtype Body = Never

    /// Shared state rendered and synchronized for this fragment.
    var state: LiveState<FragmentState> { get }

    /// Returns the component's HTML body from current state. Implement for Elementary-backed rendering.
    func body(state: FragmentState) -> Body

}

public extension ManualComponent {

    /// Default: manual fragments use no per-client state.
    var defaultState: ComponentState { [:] }

}

public extension ManualComponent where Body == Never {

    /// Leaf path: body is never called.
    func body(state: FragmentState) -> Never { fatalError() }

}

public extension ManualComponent {

    /// Renders the fragment from the current state.
    func renderCurrent(app: Application) async -> RenderResult {
        let current = await state.current
        return await render(with: current, on: app)
    }

}
