import Vapor

/// Vapor storage for Mist runtime state and configuration.
final private class MistStorage: @unchecked Sendable {
    
    var clients: MistClients?
    var components: MistComponents?
    var socketPath: [PathComponent]?
    var shouldUpgrade: (@Sendable (Request) async -> HTTPHeaders?)?
    var socketMiddleware: (any Middleware)?
    
    init() {}
    
}

private struct MistStorageKey: StorageKey { typealias Value = MistStorage }

extension Mist {

    /// Returns the Vapor storage container for Mist.
    private var _storage: MistStorage {
        if let existing = app.storage[MistStorageKey.self] { return existing }
        let new = MistStorage()
        app.storage[MistStorageKey.self] = new
        return new
    }
    
}

extension Mist {

    private struct ClientsKey: LockKey {}
    private struct ComponentsKey: LockKey {}
    private struct SocketPathKey: LockKey {}
    private struct ShouldUpgradeKey: LockKey {}
    private struct SocketMiddlewareKey: LockKey {}
    
    var _clients: MistClients {
        app.locks.lock(for: ClientsKey.self).withLock {
            if let existing = _storage.clients { return existing }
            let new = MistClients(components: _components)
            _storage.clients = new
            return new
        }
    }

    var _components: MistComponents {
        app.locks.lock(for: ComponentsKey.self).withLock {
            if let existing = _storage.components { return existing }
            let new = MistComponents(app: app)
            _storage.components = new
            return new
        }
    }

    var _socket: MistSocketConfiguration {
        MistSocketConfiguration(app: app)
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
    public struct MistSocketConfiguration {
        
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
