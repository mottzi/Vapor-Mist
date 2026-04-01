import Vapor
import Fluent

/// A fragment-backed unit refreshed from periodic polling.
public protocol MistPollingComponent: MistFragmentComponent {
    
    /// Context type returned by each polling pass.
    associatedtype MistFragmentContext: MistComponentData
    
    /// Interval between polling passes.
    var refreshInterval: Duration { get }
    
    /// Returns the current fragment context, or `nil` when nothing should render.
    func poll(on db: Database) async -> MistFragmentContext?
    
}

public extension MistPollingComponent {
    
    /// Default: poll every three seconds.
    var refreshInterval: Duration { .seconds(3) }
    
}

public extension MistPollingComponent {
    
    /// Renders the fragment from a fresh polling pass.
    func renderCurrent(app: Application) async -> String? {
        guard let context = await poll(on: app.db) else { return nil }
        return await render(with: context, using: app.leaf.renderer)
    }
    
}
