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

public func configure(using config: Mist.Configuration) async
{
    let inlineTemplates = TemplateSource()
    for component in config.components {
        guard case .inline(let template) = component.template else { continue }
        await inlineTemplates.register(name: component.name, template: template)
    }
    
    let sources = LeafSources()
    try? sources.register(source: "mist-templates", using: inlineTemplates)
    try? sources.register(source: "default", using: config.app.leaf.defaultSource)
    config.app.leaf.sources = sources
        
    await Mist.Components.shared.registerComponents(using: config)
    Mist.Socket.register(on: config.app)
}

extension Application.Leaf {

    var defaultSource: NIOLeafFiles {
        NIOLeafFiles(
            fileio: self.application.fileio,
            limits: .default,
            sandboxDirectory: self.configuration.rootDirectory,
            viewDirectory: self.configuration.rootDirectory
        )
    }

}
