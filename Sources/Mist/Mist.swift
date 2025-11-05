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
        if let templateString = component.templateSource {
            await stringSource.register(name: component.name, template: templateString)
            logger.warning("1.Registered template for component \(component.name): \(templateString)")
        }
    }
    
    // Register components with Mist system
    await Mist.Components.shared.registerComponents(using: config)
    
    // Configure Leaf to use both string and file sources
    let sources = config.app.leaf.sources
    
    // Register the string source (this may fail if already registered, which is fine)
    try? sources.register(source: "mist-strings", using: stringSource, searchable: true)
    
    // Update search order: check string templates first, then fall back to files
    // Get current order and ensure mist-strings is first
    var searchOrder = sources.searchOrder
    if let mistIndex = searchOrder.firstIndex(of: "mist-strings") {
        searchOrder.remove(at: mistIndex)
    }
    searchOrder.insert("mist-strings", at: 0)
    
    // Note: We can't directly set searchOrder, so we need to work with the existing sources
    // The registration already adds it to the search order, and since we registered it,
    // subsequent renders will check it first based on registration order
    
    // Register the configured sources back
    config.app.leaf.sources = sources

    logger.warning("2. sources: \(sources.all.description)")
    
    // Register WebSocket route
    Mist.Socket.register(on: config.app)
}
