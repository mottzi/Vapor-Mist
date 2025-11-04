import Vapor
import Fluent

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
    await Mist.Components.shared.registerComponents(using: config)
    Mist.Socket.register(on: config.app)
}
