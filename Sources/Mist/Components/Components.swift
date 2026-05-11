import Vapor

/// Runtime registry of components, storing model bindings, actions and more.
public actor Components {
    
    let app: Application
    
    init(app: Application) {
        self.app = app
    }
    
    /// Registry of components addressable by runtime name.
    var componentsByName: [String: any Component] = [:]
    
    /// Index from model type to instance components watching that model.
    var modelToInstanceComponents: [ObjectIdentifier: [any InstanceComponent]] = [:]
    
    /// Index from model type to query components driven by that model.
    var modelToQueryComponents: [ObjectIdentifier: [any QueryComponent]] = [:]
    
    /// Action dispatch table keyed by component name, then action name.
    var componentActions: [String: [String: any Action]] = [:]
    
    /// In-flight action keys used to deduplicate overlapping client requests.
    var activeRequests: Set<String> = []
    
    /// Components temporarily suppressing automatic publishes during an action cycle.
    var suspendedComponents: Set<String> = []
    
    /// Latest deliverable state for polling components, including startup synchronization.
    var pollingState: [String: PollingDeliveryState] = [:]
    
}
