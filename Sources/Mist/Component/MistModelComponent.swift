import Vapor
import Fluent

/// A renderable unit whose rendering and refresh semantics are model-driven.
public protocol MistModelComponent: MistComponent {
    
    /// Model types Mist tracks for rendering and listener registration.
    var models: [any MistModel.Type] { get }
    
    /// Decides whether a model event should refresh this component.
    func shouldUpdate<M: MistModel>(for model: M) -> Bool
    
}

public extension MistModelComponent {
    
    /// Default: refresh when the affected model type appears in `models`.
    func shouldUpdate<M: MistModel>(for model: M) -> Bool {
        models.contains { $0 == M.self }
    }

    /// Renders the component's template from model-derived context.
    func render(with modelID: UUID, state: MistComponentState? = nil, on db: Database, using renderer: ViewRenderer) async -> String? {
        
        guard let context = await makeContext(using: modelID, state: state, on: db) else { return nil }
        return await render(with: context, using: renderer)
    }
    
    /// Builds render context from all tracked models matching a shared ID.
    func makeContext(using modelID: UUID, state: MistComponentState? = nil, on db: Database) async -> ComponentContext? {
        
        var container = MistModelContext()

        for model in models {
            guard let modelData = await model.find(id: modelID, on: db) else { continue }
            container.add(modelData, as: model)
        }

        guard container.hasElements else { return nil }

        return ComponentContext(context: container, state: state ?? defaultState)
    }
    
}
