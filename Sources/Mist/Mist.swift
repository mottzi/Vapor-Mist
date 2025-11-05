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

public func Xconfigure(using config: Mist.Configuration) async {
    let logger = config.app.logger

    let templates = TemplateSource()
    
    for component in config.components {
        guard case .inline(let template) = component.template else { continue }
        await templates.register(name: component.name, template: template)
        logger.warning("Registered component \(component.name) with inline template")
    }
    
    await Mist.Components.shared.registerComponents(using: config)
    
    // Register the template source (this may fail if already registered, which is fine)
    try? config.app.leaf.sources.register(source: "mist-templates", using: templates)
    logger.warning("sources: \(config.app.leaf.sources.searchOrder.joined(separator: " -> "))")
    
    // Register WebSocket route
    Mist.Socket.register(on: config.app)
}

public func configure(using config: Mist.Configuration) async {
    let logger = config.app.logger
    
    let templates = TemplateSource()
    
    for component in config.components {
        guard case .inline(let template) = component.template else { continue }
        await templates.register(name: component.name, template: template)
        logger.warning("Registered component \(component.name) with inline template")
    }
    
    await Mist.Components.shared.registerComponents(using: config)
    
    // Create a new LeafSources and register in desired order
    let sources = LeafSources()
    
    // Register mist-templates FIRST (will be searched first)
    try? sources.register(source: "mist-templates", using: templates)
    
    // Register default file source SECOND (will be searched second)
    try? sources.register(
        source: "default",
        using: NIOLeafFiles(
            fileio: config.app.fileio,
            limits: .default,
            sandboxDirectory: config.app.leaf.configuration.rootDirectory,
            viewDirectory: config.app.leaf.configuration.rootDirectory
        )
    )
    
    // Set the new sources
    config.app.leaf.sources = sources
    
    logger.warning("sources: \(config.app.leaf.sources.searchOrder.joined(separator: " -> "))")
    
    // Register WebSocket route
    Mist.Socket.register(on: config.app)
}
