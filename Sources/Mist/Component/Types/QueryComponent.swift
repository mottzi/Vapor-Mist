import Vapor
import Fluent

/// A fragment-backed unit resolved from a query.
public protocol QueryComponent: FragmentComponent, ModelComponent {
    
    /// Model type returned by the query.
    associatedtype FragmentModel: Model
    
    /// Returns the model currently backing this fragment.
    func query(on db: Database) async throws -> FragmentModel?
    
}

public extension QueryComponent {
    
    /// Default: tracks only the queried model type.
    var models: [any Model.Type] { [FragmentModel.self] }
    
}

public extension QueryComponent {
    
    /// Renders the fragment for the model currently returned by `query(on:)`.
    func renderCurrent(app: Application) async -> RenderResult {
        let model: FragmentModel?
        do {
            model = try await query(on: app.db)
        } catch {
            app.logger.error("\(MistError.databaseFetchFailed("\(Self.self) current query", error))")
            return .failed
        }

        guard let model,
              let modelID = model.id
        else { return .absent }
        
        return await render(with: modelID, state: [:], on: app)
    }
    
}
