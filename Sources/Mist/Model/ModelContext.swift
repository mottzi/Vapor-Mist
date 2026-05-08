import Foundation

/// Collection of models used to build template rendering context.
/// Computed properties are merged when the models are encoded.
public struct ModelContext: Encodable, Sendable {
    
    /// Internal storage of models.
    private var nameToModel: [String: any Model] = [:]
    
    var hasElements: Bool { !nameToModel.isEmpty }

    /// Adds a model keyed by its lowercase Swift type name.
    public mutating func add(_ model: any Model, as modelType: any Model.Type) {
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
                let mergedModel = ModelEncoder(model: model, adding: computedProperties)
                try container.encode(mergedModel, forKey: StringCodingKey(of: name))
            }
        }
    }
    
    public init() {}
    
    /// Retrieves a strongly-typed model from the context using its Swift type name.
    public func model<M: Model>(_ type: M.Type) -> M? {
        let name = String(describing: type).lowercased()
        return nameToModel[name] as? M
    }
    
    /// Retrieves a model dynamically by its lowercase type name.
    public func model(named name: String) -> (any Model)? {
        nameToModel[name.lowercased()]
    }
    
}

/// Render context for one model-backed component and its per-client state.
@dynamicMemberLookup
public struct ComponentContext: Encodable, Sendable {
    
    public let context: ModelContext
    public let state: DynamicStateProxy
    
    public init(context: ModelContext, state: ComponentState) {
        self.context = context
        self.state = DynamicStateProxy(raw: state)
    }
    
    /// Retrieves a strongly-typed model from the underlying model context.
    public func model<M: Model>(_ type: M.Type) -> M? {
        context.model(type)
    }
    
    /// Returns a dynamic proxy for the given lowercase model name.
    public subscript(dynamicMember name: String) -> DynamicModel? {
        guard let model = context.model(named: name) else { return nil }
        return DynamicModel(model: model)
    }
    
}

/// Render context for components that render multiple model-backed entries.
public struct ComponentContexts: Encodable, Sendable {
    
    public let contexts: [ModelContext]
    
    public init(contexts: [ModelContext]) {
        self.contexts = contexts
    }
    
    public static var empty: ComponentContexts { ComponentContexts(contexts: []) }
    
}
