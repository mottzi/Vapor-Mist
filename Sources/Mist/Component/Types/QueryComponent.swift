import Vapor
import Fluent

/// A fragment-backed unit resolved from a query.
public protocol QueryComponent: FragmentComponent, ModelComponent {

    /// Model type returned by the query.
    associatedtype FragmentModel: Model

    /// Returns the model currently backing this fragment.
    func query(on db: Database) async throws -> FragmentModel?

    /// The strongly typed context representation for the component. Defaults to raw `ComponentContext`.
    associatedtype Context: Encodable = ComponentContext

    /// HTML body type returned by Elementary-backed components. Defaults to `LeafRenderPath` for Leaf-backed components.
    associatedtype Body = LeafRenderPath

    /// Maps the raw model context into the component's strongly typed context.
    func context(from context: ComponentContext) -> Context

    /// Returns the component's HTML body from current state. Implement for Elementary-backed rendering.
    func body(context: Context) -> Body

}

public extension QueryComponent where Context == ComponentContext {

    /// Default: passes the raw component context directly to the body function.
    func context(from context: ComponentContext) -> ComponentContext { context }

}

public extension QueryComponent where Context == ComponentContext, Body == LeafRenderPath {

    /// Leaf path: body is never called.
    func body(context: ComponentContext) -> LeafRenderPath { fatalError("Leaf components do not use a body function") }

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

    /// Renders the current query result using per-client component state.
    func renderCurrent(app: Application, state: ComponentState) async -> RenderResult {
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

        return await render(with: modelID, state: state, on: app)
    }
    
}
