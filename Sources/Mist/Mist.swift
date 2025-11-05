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
    let logger = config.app.logger

    // Create the in-memory template source for components with inline templates
    let templateSource = TemplateSource()
    
    // Register all components and populate template source with inline templates
    for component in config.components {
        guard case .inline(let template) = component.template else { continue }
        await templateSource.register(name: component.name, template: template)
        logger.debug("Registered component \(component.name) with inline template")
    }
    
    // Register components with Mist system
    await Mist.Components.shared.registerComponents(using: config)
    
    // Configure Leaf to use both inline and file sources
    let sources = config.app.leaf.sources
    
    // Register the template source (this may fail if already registered, which is fine)
    try? sources.register(source: "mist-templates", using: templateSource)
    
    config.app.leaf.sources = sources

    logger.debug("sources: \(sources.all.description)")
    
    // Register WebSocket route
    Mist.Socket.register(on: config.app)
}
