import Vapor

/// A stateful fragment that renders and updates from manually updated state.
public protocol ManualComponent: FragmentComponent {

    /// State type rendered by this fragment.
    associatedtype FragmentState: ComponentData

    /// HTML body type returned by Elementary-backed components. Defaults to `LeafRenderPath` for Leaf-backed components.
    associatedtype Body = LeafRenderPath

    /// HTML body type returned when rendering with per-client component state. Defaults to `Body`.
    associatedtype ComponentStateBody = Body

    /// Shared state rendered and synchronized for this fragment.
    var state: LiveState<FragmentState> { get }

    /// Returns the component's HTML body from current state. Implement for Elementary-backed rendering.
    func body(state: FragmentState) -> Body

    /// Returns the component's HTML body from current state and per-client component state.
    func body(state: FragmentState, componentState: ComponentState) -> ComponentStateBody

    /// Renders the fragment using per-client component state.
    func renderCurrent(app: Application, state: ComponentState) async -> RenderResult

}

public extension ManualComponent {

    /// Default: manual fragments use no per-client state.
    var defaultState: ComponentState { [:] }

}

public extension ManualComponent where ComponentStateBody == Body {

    /// Default: manual fragments ignore per-client component state.
    func body(state: FragmentState, componentState: ComponentState) -> Body {
        body(state: state)
    }

}

public extension ManualComponent where Body == LeafRenderPath {

    /// Leaf path: body is never called.
    func body(state: FragmentState) -> LeafRenderPath { fatalError("Leaf components do not use a body function") }

}

public extension ManualComponent {

    /// Renders the fragment from the current state.
    func renderCurrent(app: Application) async -> RenderResult {
        let current = await state.current
        return await render(with: current, on: app)
    }

    /// Renders the fragment from the current state and per-client component state.
    func renderCurrent(app: Application, state componentState: ComponentState) async -> RenderResult {
        await renderCurrentManualFragment(app: app, state: componentState)
    }

}
