import Vapor
import Fluent

/// A fragment-backed unit resolved from a query.
public protocol MistQueryComponent: MistFragmentComponent, MistModelComponent {
    
    /// Model type returned by the query.
    associatedtype FragmentModel: MistModel
    
    /// Returns the model currently backing this fragment.
    func query(on db: Database) async -> FragmentModel?
    
}

public extension MistQueryComponent {
    
    /// Default: tracks only the queried model type.
    var models: [any MistModel.Type] { [FragmentModel.self] }
    
}

public extension MistQueryComponent {
    
    /// Renders the fragment for the model currently returned by `query(on:)`.
    func renderCurrent(app: Application) async -> String? {
        
        guard let model = await query(on: app.db),
              let modelID = model.id
        else { return nil }
        
        return await render(with: modelID, state: [:], on: app.db, using: app.leaf.renderer)
    }
    
}
