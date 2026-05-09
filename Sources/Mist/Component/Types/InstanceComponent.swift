import Vapor
import Fluent

/// A unit addressed and updated per model instance.
public protocol InstanceComponent: ModelComponent, Sendable {

    /// Returns the model instances used for initial rendering.
    /// Throws when the database query fails; returns an empty array when no records exist.
    func allModels(on db: Database) async throws -> [any Model]
    
    /// The strongly typed context representation for the component. Defaults to raw `ComponentContext`.
    associatedtype Context: Encodable = ComponentContext

    /// HTML body type returned by Elementary-backed components. Defaults to `LeafRenderPath` for Leaf-backed components.
    associatedtype Body = LeafRenderPath

    /// Maps the raw model context into the component's strongly typed context.
    func context(from context: ComponentContext) -> Context

    /// Returns the component's HTML body from current state. Implement for Elementary-backed rendering.
    func body(context: Context) -> Body

}

public extension InstanceComponent where Context == ComponentContext {

    /// Default: passes the raw component context directly to the body function.
    func context(from context: ComponentContext) -> ComponentContext { context }

}

public extension InstanceComponent where Context == ComponentContext, Body == LeafRenderPath {

    /// Leaf path: body is never called.
    func body(context: ComponentContext) -> LeafRenderPath { fatalError("Leaf components do not use a body function") }

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

