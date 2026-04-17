import Vapor
import Fluent

/// A unit addressed and updated per model instance.
public protocol InstanceComponent: ModelComponent {

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
