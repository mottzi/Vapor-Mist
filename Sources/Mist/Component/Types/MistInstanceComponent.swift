import Vapor
import Fluent

/// A unit addressed and updated per model instance.
public protocol MistInstanceComponent: MistModelComponent {
    
    /// Returns the model instances used for initial rendering.
    func allModels(on db: Database) async -> [any MistModel]?
    
}

public extension MistInstanceComponent {
    
    /// Default: loads all records of the first tracked model type.
    func allModels(on db: Database) async -> [any MistModel]? {
        guard let primaryModelType = models.first else { return nil }
        return await primaryModelType.findAll(on: db)        
    }
    
    /// Builds render context for all model instances returned by `allModels(on:)`.
    func makeContext(ofAll db: Database) async -> ComponentContexts {
        
        var modelContainers: [MistModelContext] = []

        guard let primaryModels = await allModels(on: db) else { return .empty }

        for primaryModel in primaryModels {
            guard let modelID = primaryModel.id else { continue }
            guard let modelContext = await makeContext(using: modelID, on: db) else { continue }
            modelContainers.append(modelContext.context)
        }

        guard modelContainers.isEmpty == false else { return .empty }

        return ComponentContexts(contexts: modelContainers)
    }
    
}
