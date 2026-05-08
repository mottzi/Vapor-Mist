import Vapor
import Fluent

/// A renderable unit whose rendering and refresh semantics are model-driven.
public protocol ModelComponent: Component {

    /// Model types Mist tracks for rendering and listener registration.
    var models: [any Model.Type] { get }

    /// Decides whether a model event should refresh this component.
    func shouldUpdate<M: Model>(for model: M) -> Bool

}

public extension ModelComponent {

    /// Default: refresh when the affected model type appears in `models`.
    func shouldUpdate<M: Model>(for model: M) -> Bool {
        models.contains { $0 == M.self }
    }

    /// Renders the component's template from model-derived context.
    /// Logs and returns `.failed` when the database fetch throws; returns `.absent` when the model is not found.
    func render(with modelID: UUID, state: ComponentState? = nil, on app: Application) async -> RenderResult {
        await app.mist.renderer.renderModelComponent(self, modelID: modelID, state: state)
    }

    /// Builds render context from all tracked models matching a shared ID.
    func makeContext(using modelID: UUID, state: ComponentState? = nil, on db: Database) async throws -> ComponentContext? {

        var container = ModelContext()

        for model in models {
            guard let modelData = try await model.find(id: modelID, on: db) else { continue }
            container.add(modelData, as: model)
        }

        guard container.hasElements else { return nil }

        return ComponentContext(context: container, state: state ?? defaultState)
    }

    /// Builds render context reusing an already-loaded primary model.
    /// Only fetches secondary tracked model types by ID; avoids re-fetching the primary.
    func makeContext(from primaryModel: any Model, state: ComponentState? = nil, on db: Database) async throws -> ComponentContext? {

        guard let primaryModelType = models.first else { return nil }

        var container = ModelContext()
        container.add(primaryModel, as: primaryModelType)

        if let modelID = primaryModel.id {
            for modelType in models.dropFirst() {
                guard let modelData = try await modelType.find(id: modelID, on: db) else { continue }
                container.add(modelData, as: modelType)
            }
        }

        guard container.hasElements else { return nil }

        return ComponentContext(context: container, state: state ?? defaultState)
    }

}

/// A model component that builds the concrete context rendered by its template.
///
/// Leaf-backed components use the default `ModelComponent.makeContext(...)`
/// methods above, which produce `ComponentContext` and preserve the
/// `ModelContext`/`ModelEncoder` pipeline. Strongly typed template backends can
/// conform to this refinement so the renderer receives their native context
/// directly instead of the dynamic Leaf wrapper.
public protocol TypedModelComponent: ModelComponent {

    /// Concrete context consumed by this component's template backend.
    associatedtype TemplateContext: Encodable

    /// Builds a template-native context for a model identity.
    func makeTemplateContext(
        using modelID: UUID,
        state: ComponentState?,
        on db: Database
    ) async throws -> TemplateContext?

    /// Builds a template-native context from an already-loaded primary model.
    func makeTemplateContext(
        from primaryModel: any Model,
        state: ComponentState?,
        on db: Database
    ) async throws -> TemplateContext?

    /// Type-erased bridge used by the runtime renderer.
    func makeAnyTemplateContext(
        using modelID: UUID,
        state: ComponentState?,
        on db: Database
    ) async throws -> (any Encodable)?

    /// Type-erased bridge used by instance collection rendering.
    func makeAnyTemplateContext(
        from primaryModel: any Model,
        state: ComponentState?,
        on db: Database
    ) async throws -> (any Encodable)?

}

public extension TypedModelComponent {

    /// Default identity lookup mirrors the Leaf path: load the primary tracked
    /// model by ID, then let the component assemble its native context.
    func makeTemplateContext(
        using modelID: UUID,
        state: ComponentState? = nil,
        on db: Database
    ) async throws -> TemplateContext? {

        guard let primaryModelType = models.first,
              let primaryModel = try await primaryModelType.find(id: modelID, on: db)
        else { return nil }

        return try await makeTemplateContext(from: primaryModel, state: state, on: db)
    }

    func makeAnyTemplateContext(
        using modelID: UUID,
        state: ComponentState? = nil,
        on db: Database
    ) async throws -> (any Encodable)? {
        try await makeTemplateContext(using: modelID, state: state, on: db)
    }

    func makeAnyTemplateContext(
        from primaryModel: any Model,
        state: ComponentState? = nil,
        on db: Database
    ) async throws -> (any Encodable)? {
        try await makeTemplateContext(from: primaryModel, state: state, on: db)
    }

}
