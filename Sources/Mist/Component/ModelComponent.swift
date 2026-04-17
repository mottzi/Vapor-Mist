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
        let context: ComponentContext?
        do { context = try await makeContext(using: modelID, state: state, on: app.db) }
        catch { app.logger.error("\(MistError.databaseFetchFailed("\(Self.self) id=\(modelID)", error))"); return .failed }
        guard let context else { return .absent }
        return await render(with: context, on: app)
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
