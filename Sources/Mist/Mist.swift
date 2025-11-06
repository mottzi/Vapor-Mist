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
    
    await config.app.mist.clients.broadcast(.init(component: "", id: UUID(), html: ""))
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

extension Application {
    
    public var mist: MistDependency {
        .init(application: self)
    }
    
    public struct MistDependency {
        
        public let application: Application
        
        public var clients: Mist.Clients {
            if let existing = storage.clients { return existing }
            let new = Mist.Clients()
            storage.clients = new
            return new
        }
        
        var storage: Storage {
            if let existing = self.application.storage[Key.self] { return existing }
            let new = Storage()
            self.application.storage[Key.self] = new
            return new
        }
        
        struct Key: StorageKey {
            
            typealias Value = Storage
            
        }
        
        final class Storage: @unchecked Sendable {
            
            var clients: Mist.Clients?
            
            init() {}
            
        }
        
    }
}
