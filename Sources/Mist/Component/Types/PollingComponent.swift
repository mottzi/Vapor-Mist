import Vapor
import Fluent

/// A fragment-backed unit refreshed from periodic polling.
public protocol PollingComponent: FragmentComponent {
    
    /// Context type returned by each polling pass.
    associatedtype FragmentContext: ComponentData
    
    /// Interval between polling passes.
    var refreshInterval: Duration { get }
    
    /// Returns the current fragment context, or `nil` when nothing should render.
    func poll(on db: Database) async -> FragmentContext?
    
}

public extension PollingComponent {
    
    /// Default: poll every three seconds.
    var refreshInterval: Duration { .seconds(3) }
    
}

public extension PollingComponent {
    
    /// Renders the fragment from a fresh polling pass.
    func renderCurrent(app: Application) async -> String? {
        guard let context = await poll(on: app.db) else { return nil }
        return await render(with: context, using: app.leaf.renderer)
    }
    
}
