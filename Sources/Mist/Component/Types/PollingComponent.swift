import Vapor
import Fluent

/// A fragment-backed unit refreshed from periodic polling.
public protocol PollingComponent: FragmentComponent {

    /// Context type returned by each polling pass.
    associatedtype FragmentContext: ComponentData

    /// HTML body type returned by Elementary-backed components. Defaults to `Never` for Leaf-backed components.
    associatedtype Body = Never

    /// Interval between polling passes.
    var refreshInterval: Duration { get }

    /// Returns the current fragment context, or `nil` when nothing should render.
    func poll(on db: Database) async -> FragmentContext?

    /// Returns the component's HTML body from polling context. Implement for Elementary-backed rendering.
    func body(context: FragmentContext) -> Body

}

public extension PollingComponent {

    /// Default: poll every three seconds.
    var refreshInterval: Duration { .seconds(3) }

}

public extension PollingComponent where Body == Never {

    /// Leaf path: body is never called.
    func body(context: FragmentContext) -> Never { fatalError() }

}

public extension PollingComponent {

    /// Renders the fragment from a fresh polling pass.
    func renderCurrent(app: Application) async -> RenderResult {
        guard let context = await poll(on: app.db) else { return .absent }
        return await render(with: context, on: app)
    }

}
