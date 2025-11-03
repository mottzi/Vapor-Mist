import Vapor
import Fluent

public func configure(using config: Mist.Configuration) async
{
    // registers components in config with MistComponents
    await Mist.Components.shared.registerComponents(definedIn: config)
    
    // registers subscription socket on server app
    Mist.Socket.register(on: config.app)
}

public struct Configuration: Sendable
{
    // database configuration
    let db: DatabaseID?
    
    // reference to application
    let app: Application
    
    // configured components
    let components: [any Mist.Component]
    
    // public initializer
    public init(for app: Application,
                components: [any Mist.Component],
                on db: DatabaseID? = nil)
    {
        self.app = app
        self.db = db
        self.components = components
    }
}
