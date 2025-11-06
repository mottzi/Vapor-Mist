import Vapor
import Fluent

public protocol Component: Sendable {
    
    var name: String { get }
    var template: TemplateType { get }
    var models: [any Mist.Model.Type] { get }
    
    func render(id: UUID, on db: Database, using renderer: ViewRenderer) async -> String?
    func shouldUpdate<M: Mist.Model>(for model: M) -> Bool
    
}

public extension Mist.Component {
    
    var name: String { String(describing: Self.self) }
    var template: TemplateType { .file(path: name) }
    
}

public extension Mist.Component {
    
    func render(id: UUID, on db: Database, using renderer: ViewRenderer) async -> String?
    {
        guard let context = await makeContext(of: id, in: db) else { return nil }
        let templateName = switch template {
            case .file(let path): path
            case .inline: name
        }
        guard let buffer = try? await renderer.render(templateName, context).data else { return nil }
        return String(buffer: buffer)
    }
    
    func shouldUpdate<M: Mist.Model>(for model: M) -> Bool
    {
        return models.contains { $0 == M.self }
    }
    
}

public extension Mist.Component {
    
    func makeContext(of componentID: UUID, in db: Database) async -> SingleComponentContext?
    {
        var container = Mist.ModelContainer()
        
        for model in models
        {
            guard let modelData = await model.find(componentID, db) else { continue }
            let modelName = String(describing: model).lowercased()
            
            container.add(modelData, for: modelName)
        }
        
        guard container.isEmpty == false else { return nil }
        
        return SingleComponentContext(component: container)
    }
    
    func makeContext(ofAll db: Database) async -> MultipleComponentContext
    {
        var modelContainers: [Mist.ModelContainer] = []

        guard let primaryModelType = models.first else { return .empty }
        guard let primaryModels = await primaryModelType.findAll(db) else { return .empty }

        for primaryModel in primaryModels
        {
            guard let modelID = primaryModel.id else { continue }
            guard let modelContext = await makeContext(of: modelID, in: db) else { continue }

            modelContainers.append(modelContext.component)
        }

        guard modelContainers.isEmpty == false else { return .empty }

        return Mist.MultipleComponentContext(components: modelContainers)
    }
    
}

public enum TemplateType: Sendable {
    
    case file(path: String)
    case inline(template: String)
    
}
