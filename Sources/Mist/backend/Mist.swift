import Fluent
import Leaf
import LeafKit
import Vapor

extension Application
{
    public struct Mist
    {
        public let app: Application
        public var clients: MistClients { _clients }
        public var components: Components { _components }
        public var socketPath: [PathComponent] 
        {
            get { _socketPath }
            nonmutating set { _socketPath = newValue }
        }

        public func use(_ components: [any Component]) async
        {
            await configure(components, on: app)
        }

        public func use(_ components: any Component...) async
        {
            await configure(components, on: app)
        }
    }

    public var mist: Mist { Mist(app: self) }
}

extension Application.Mist
{
    final class Storage: @unchecked Sendable
    {
        init() {}
        var clients: Mist.Clients?
        var components: Mist.Components?
        var socketPath: [PathComponent]?
    }

    private struct Key: StorageKey { typealias Value = Storage }

    var _storage: Storage
    {
        if let existing = app.storage[Key.self] { return existing }
        let new = Storage()
        app.storage[Key.self] = new
        return new
    }
}

extension Application.Mist
{
    private struct ClientsKey: LockKey {}
    private struct ComponentsKey: LockKey {}
    private struct SocketPathKey: LockKey {}

    var _clients: Mist.Clients
    {
        return app.locks.lock(for: ClientsKey.self).withLock
        {
            if let existing = _storage.clients { return existing }
            let new = Mist.Clients(components: _components)
            _storage.clients = new
            return new
        }
    }

    var _components: Mist.Components
    {
        return app.locks.lock(for: ComponentsKey.self).withLock
        {
            if let existing = _storage.components { return existing }
            let new = Mist.Components()
            _storage.components = new
            return new
        }
    }

    var _socketPath: [PathComponent]
    {
        get
        {
            return app.locks.lock(for: SocketPathKey.self).withLock
            {
                return _storage.socketPath ?? ["mist", "ws"]
            }
        }
        nonmutating set
        {
            app.locks.lock(for: SocketPathKey.self).withLock
            {
                _storage.socketPath = newValue
            }
        }
    }
}
