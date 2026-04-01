import Vapor

extension Mist {
    
    /// Vapor storage for Mist runtime state and configuration.
    final class Storage: @unchecked Sendable {
        
        var clients: Clients?
        var components: Components?
        var socketPath: [PathComponent]?
        var shouldUpgrade: (@Sendable (Request) async -> HTTPHeaders?)?
        var socketMiddleware: (any Middleware)?
        
        init() {}
        
    }

    private struct Key: StorageKey { typealias Value = Storage }

    /// Returns the Vapor storage container for Mist.
    var _storage: Storage {
        if let existing = app.storage[Key.self] { return existing }
        let new = Storage()
        app.storage[Key.self] = new
        return new
    }
    
}

extension Mist {

    private struct ClientsKey: LockKey {}
    private struct ComponentsKey: LockKey {}
    private struct SocketPathKey: LockKey {}
    private struct ShouldUpgradeKey: LockKey {}
    private struct SocketMiddlewareKey: LockKey {}
    
    var _clients: Clients {
        app.locks.lock(for: ClientsKey.self).withLock {
            if let existing = _storage.clients { return existing }
            let new = Clients(components: _components)
            _storage.clients = new
            return new
        }
    }

    var _components: Components {
        app.locks.lock(for: ComponentsKey.self).withLock {
            if let existing = _storage.components { return existing }
            let new = Components(app: app)
            _storage.components = new
            return new
        }
    }

    var _socket: SocketConfiguration {
        SocketConfiguration(app: app)
    }

    var _socketPath: [PathComponent] {
        get {
            app.locks.lock(for: SocketPathKey.self).withLock {
                _storage.socketPath ?? ["mist", "ws"]
            }
        }
        nonmutating set {
            app.locks.lock(for: SocketPathKey.self).withLock {
                _storage.socketPath = newValue
            }
        }
    }
    
    var _shouldUpgrade: @Sendable (Request) async -> HTTPHeaders? {
        get {
            app.locks.lock(for: ShouldUpgradeKey.self).withLock {
                _storage.shouldUpgrade ?? { _ in HTTPHeaders() }
            }
        }
        nonmutating set {
            app.locks.lock(for: ShouldUpgradeKey.self).withLock {
                _storage.shouldUpgrade = newValue
            }
        }
    }
    
    var _socketMiddleware: (any Middleware)? {
        get {
            app.locks.lock(for: SocketMiddlewareKey.self).withLock {
                _storage.socketMiddleware
            }
        }
        nonmutating set {
            app.locks.lock(for: SocketMiddlewareKey.self).withLock {
                _storage.socketMiddleware = newValue
            }
        }
    }
    
}

extension Mist {
    
    /// User-configurable websocket registration settings.
    public struct SocketConfiguration {
        
        let app: Application

        public var path: [PathComponent] {
            get { app.mist._socketPath }
            nonmutating set { app.mist._socketPath = newValue }
        }
        
        public var shouldUpgrade: @Sendable (Request) async -> HTTPHeaders? {
            get { app.mist._shouldUpgrade }
            nonmutating set { app.mist._shouldUpgrade = newValue }
        }
        
        public var middleware: (any Middleware)? {
            get { app.mist._socketMiddleware }
            nonmutating set { app.mist._socketMiddleware = newValue }
        }
        
    }
    
}
