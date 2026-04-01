import Foundation

/// Collection of models used to build template rendering context.
/// Computed properties are merged when the models are encoded.
public struct MistModelContext: Encodable {
    
    /// Internal storage of models.
    private var nameToModel: [String: any MistModel] = [:]
    
    var hasElements: Bool { !nameToModel.isEmpty }

    /// Adds a model keyed by its lowercase Swift type name.
    public mutating func add(_ model: any MistModel, as modelType: any MistModel.Type) {
        let name = String(describing: modelType).lowercased()
        nameToModel[name] = model
    }
    
    /// Encodes each model using its name as key, merging computed propoerties.
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        for (name, model) in nameToModel {
            let computedProperties = model.computedProperties
            if computedProperties.isEmpty {
                try container.encode(model, forKey: StringCodingKey(of: name))
            } else {
                let mergedModel = MistModelEncoder(model: model, adding: computedProperties)
                try container.encode(mergedModel, forKey: StringCodingKey(of: name))
            }
        }
    }
    
    public init() {}
    
}

/// Render context for one model-backed component and its per-client state.
public struct ComponentContext: Encodable {
    
    public let context: MistModelContext
    public let state: MistComponentState
    
    public init(context: MistModelContext, state: MistComponentState) {
        self.context = context
        self.state = state
    }
    
}

/// Render context for components that render multiple model-backed entries.
public struct ComponentContexts: Encodable {
    
    public let contexts: [MistModelContext]
    
    public init(contexts: [MistModelContext]) {
        self.contexts = contexts
    }
    
    public static var empty: ComponentContexts { ComponentContexts(contexts: []) }
    
}
