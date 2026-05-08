import Vapor
import Fluent

/// A unit addressed and updated per model instance.
public protocol InstanceComponent: ModelComponent, Sendable {

    /// Returns the model instances used for initial rendering.
    /// Throws when the database query fails; returns an empty array when no records exist.
    func allModels(on db: Database) async throws -> [any Model]

}

public extension InstanceComponent {

    /// Default: loads all records of the first tracked model type.
    func allModels(on db: Database) async throws -> [any Model] {
        guard let primaryModelType = models.first else { return [] }
        return try await primaryModelType.findAll(on: db)
    }

    /// Builds render context for all model instances returned by `allModels(on:)`.
    /// Throws when `allModels` fails (total failure). Per-instance context errors are logged and skipped.
    func makeContext(ofAll db: Database) async throws -> ComponentContexts {

        var modelContainers: [ModelContext] = []

        for primaryModel in try await allModels(on: db) {
            do {
                guard let modelContext = try await makeContext(from: primaryModel, on: db) else { continue }
                modelContainers.append(modelContext.context)
            } catch {
                db.logger.error("\(MistError.databaseFetchFailed("\(type(of: primaryModel)) id=\(primaryModel.id?.uuidString ?? "nil")", error))")
            }
        }

        guard !modelContainers.isEmpty else { return .empty }

        return ComponentContexts(contexts: modelContainers)
    }

}

/// Strongly typed instance component support for template backends that should
/// receive Swift context values directly.
public protocol TypedInstanceComponent: InstanceComponent, TypedModelComponent {

    /// Primary model that represents one rendered instance.
    associatedtype InstanceModel: Model

    /// Returns the primary model instances used for initial rendering.
    func allInstances(on db: Database) async throws -> [InstanceModel]

    /// Builds a template-native context from the typed primary model.
    func makeTemplateContext(
        from primaryModel: InstanceModel,
        state: ComponentState?,
        on db: Database
    ) async throws -> TemplateContext?

}

public extension TypedInstanceComponent {

    /// Default: typed instance components track and render their primary model.
    var models: [any Model.Type] { [InstanceModel.self] }

    /// Default: loads all records of the primary typed model.
    func allInstances(on db: Database) async throws -> [InstanceModel] {
        try await InstanceModel.query(on: db).all()
    }

    /// Bridges the existing dynamic Mist instance API to the typed primary
    /// query, preserving registration and delivery behavior.
    func allModels(on db: Database) async throws -> [any Model] {
        try await allInstances(on: db)
    }

    func makeTemplateContext(
        using modelID: UUID,
        state: ComponentState? = nil,
        on db: Database
    ) async throws -> TemplateContext? {

        guard let primaryModel = try await InstanceModel.find(modelID, on: db) else { return nil }
        return try await makeTemplateContext(from: primaryModel, state: state, on: db)
    }

    func makeTemplateContext(
        from primaryModel: any Model,
        state: ComponentState? = nil,
        on db: Database
    ) async throws -> TemplateContext? {

        guard let primaryModel = primaryModel as? InstanceModel else { return nil }
        return try await makeTemplateContext(from: primaryModel, state: state, on: db)
    }

    /// Builds native contexts for initial server-side rendering of all
    /// instances, including default state so Elementary rows can render the same
    /// shape used later during per-client updates.
    func makeTemplateContexts(ofAll db: Database) async throws -> [TemplateContext] {

        var contexts: [TemplateContext] = []

        for primaryModel in try await allInstances(on: db) {
            do {
                guard let context = try await makeTemplateContext(
                    from: primaryModel,
                    state: defaultState,
                    on: db
                ) else { continue }

                contexts.append(context)
            } catch {
                db.logger.error("\(MistError.databaseFetchFailed("\(type(of: primaryModel)) id=\(primaryModel.id?.uuidString ?? "nil")", error))")
            }
        }

        return contexts
    }

}
