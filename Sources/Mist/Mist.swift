import Vapor
import Fluent
import Leaf
import LeafKit

public struct Configuration: Sendable {

    let app: Application
    let db: DatabaseID?
    let components: [any Mist.Component]
    
    public init(
        for app: Application,
        components: [any Mist.Component],
        on db: DatabaseID? = nil
    ) {
        self.app = app
        self.db = db
        self.components = components
    }
    
}

public func configure(using config: Mist.Configuration) async {
    
    let logger = Logger(label: "Mist")
    // Create the in-memory string source for components with inline templates
    let stringSource = MistStringSource()
    
    // Register all components and populate string source with inline templates
    for component in config.components {
        guard case .inline(let template) = component.template else { continue }
        await stringSource.register(name: component.name, template: template)
        logger.warning("1. Registered template for component \(component.name): \(template)")
    }
    
    // Register components with Mist system
    await Mist.Components.shared.registerComponents(using: config)
    
    // Configure Leaf to use both string and file sources
    let sources = config.app.leaf.sources
    
    // Register the string source (this may fail if already registered, which is fine)
    try? sources.register(source: "mist-strings", using: stringSource, searchable: true)
    
    config.app.leaf.sources = sources
    
    // Register WebSocket route
    Mist.Socket.register(on: config.app)
}
