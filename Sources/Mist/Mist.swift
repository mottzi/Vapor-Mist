import Vapor
import Fluent
import Leaf
import LeafKit

extension Application {
    
    public struct MistDependency {
        
        public let application: Application
        
        public var clients: Mist.Clients { _clients }
        
    }
    
    public var mist: MistDependency { .init(application: self) }
    
}

extension Application.MistDependency {
    
    public func use(_ components: [any Component]) async
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
    
    public func use(_ components: any Component...) async {
        await use(components)
    }
    
}

extension Application.MistDependency {
    
    struct Key: StorageKey {
        typealias Value = Storage
    }
    
    final class Storage: @unchecked Sendable {
        init() {}
        var clients: Mist.Clients?
    }
    
    var storage: Storage {
        if let existing = self.application.storage[Key.self] { return existing }
        let new = Storage()
        application.storage[Key.self] = new
        return new
    }
    
    var _clients: Mist.Clients {
        if let existing = storage.clients { return existing }
        let new = Mist.Clients()
        storage.clients = new
        return new
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
