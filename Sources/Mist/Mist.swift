import Vapor
import Fluent
import Leaf
import LeafKit

extension Application {
    
    public struct MistDependency {
        
        public let application: Application
        
        public func use(components: [any Component], with db: DatabaseID? = nil) async
        {
            let inlineTemplates = TemplateSource()
            for component in components {
                guard case .inline(let template) = component.template else { continue }
                await inlineTemplates.register(name: component.name, template: template)
            }
            
            let sources = LeafSources()
            try? sources.register(source: "mist-templates", using: inlineTemplates)
            try? sources.register(source: "default", using: application.leaf.defaultSource)
            application.leaf.sources = sources
            
            await Components.shared.registerComponents(components, with: application)
            Socket.register(on: application)
        }
        
    }
    
}

extension Application {
    
    public var mist: MistDependency {
        .init(application: self)
    }
    
}

extension Application.MistDependency {
    
    public var clients: Mist.Clients {
        if let existing = storage.clients { return existing }
        let new = Mist.Clients()
        storage.clients = new
        return new
    }
    
    var storage: Storage {
        if let existing = self.application.storage[Key.self] { return existing }
        let new = Storage()
        application.storage[Key.self] = new
        return new
    }
    
    final class Storage: @unchecked Sendable {
        init() {}
        var clients: Mist.Clients?
    }
    
    struct Key: StorageKey {
        typealias Value = Storage
    }
    
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
