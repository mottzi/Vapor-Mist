import Vapor

/// Message exchanged between clients and the runtime over a socket.
enum MistMessage: Codable {
    
    case subscribe(component: String)
    case action(component: String, targetID: UUID?, action: String)

    case text(message: String)
    case actionResult(component: String, targetID: UUID?, action: String, result: ActionResult, message: String)

    case createInstanceComponent(component: String, modelID: UUID, html: String)
    case updateInstanceComponent(component: String, modelID: UUID, html: String)
    case deleteInstanceComponent(component: String, modelID: UUID)

    case updateQueryComponent(component: String, html: String)
    case deleteQueryComponent(component: String)
    
}

extension MistClients {
    
    /// Encodes and sends a typed socket message to one client.
    private func send<T: SendableMessage>(message: T, to clientID: UUID) {
        
        guard let client = clients.first(where: { $0.clientID == clientID }) else { return }
        guard let jsonData = try? JSONEncoder().encode(message.wireFormat) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        client.socket.eventLoop.execute { client.socket.send(jsonString, promise: nil) }
    }
    
    func send(_ message: String, to clientID: UUID)                     { send(MistMessage.Text(message: message), to: clientID) }
    func send(_ message: MistMessage.Text, to clientID: UUID)               { send(message: message, to: clientID) }
    func send(_ actionResult: MistMessage.ActionResultMessage, to clientID: UUID) { send(message: actionResult, to: clientID) }
    func send(_ create: MistMessage.InstanceCreate, to clientID: UUID)      { send(message: create, to: clientID) }
    func send(_ update: MistMessage.InstanceUpdate, to clientID: UUID)      { send(message: update, to: clientID) }
    func send(_ update: MistMessage.QueryUpdate, to clientID: UUID)         { send(message: update, to: clientID) }
    func send(_ delete: MistMessage.QueryDelete, to clientID: UUID)         { send(message: delete, to: clientID) }
    
}

extension MistClients {
    
    /// Encodes and broadcasts a typed socket message to all subscribers of a component.
    private func broadcast<T: BroadcastableMessage>(message: T) {
        
        guard let jsonData = try? JSONEncoder().encode(message.wireFormat) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let sockets = getSubscribers(of: message.component).map { $0.socket }

        for socket in sockets { socket.eventLoop.execute { socket.send(jsonString, promise: nil) } }
    }

    func broadcast(_ create: MistMessage.InstanceCreate) { broadcast(message: create) }
    func broadcast(_ update: MistMessage.InstanceUpdate) { broadcast(message: update) }
    func broadcast(_ delete: MistMessage.InstanceDelete) { broadcast(message: delete) }
    func broadcast(_ update: MistMessage.QueryUpdate)    { broadcast(message: update) }
    func broadcast(_ delete: MistMessage.QueryDelete)    { broadcast(message: delete) }
    
}

/// These wrappers keep `Message` as the single wire format while expressing routing intent in types.
/// A payload can be sendable, broadcastable, or both, instead of leaving that implicit.
/// That keeps call sites narrower and prevents routing a message in unsupported ways at compile time.

protocol SendableMessage {
    var wireFormat: MistMessage { get }
}

protocol BroadcastableMessage {
    var component: String { get }
    var wireFormat: MistMessage { get }
}

extension MistMessage {
    
    struct Text: SendableMessage {
        let message: String
        var wireFormat: MistMessage { .text(message: message) }
    }

    struct ActionResultMessage: SendableMessage {
        let component: String
        let targetID: UUID?
        let action: String
        let result: ActionResult
        let message: String

        var wireFormat: MistMessage { .actionResult(component: component, targetID: targetID, action: action, result: result, message: message) }
    }
    
}

extension MistMessage {
    
    struct InstanceCreate: BroadcastableMessage, SendableMessage {
        let component: String
        let modelID: UUID
        let html: String
        var wireFormat: MistMessage { .createInstanceComponent(component: component, modelID: modelID, html: html) }
    }

    struct InstanceUpdate: BroadcastableMessage, SendableMessage {
        let component: String
        let modelID: UUID
        let html: String
        var wireFormat: MistMessage { .updateInstanceComponent(component: component, modelID: modelID, html: html) }
    }

    struct InstanceDelete: BroadcastableMessage {
        let component: String
        let modelID: UUID
        var wireFormat: MistMessage { .deleteInstanceComponent(component: component, modelID: modelID) }
    }

    struct QueryUpdate: BroadcastableMessage, SendableMessage {
        let component: String
        let html: String
        var wireFormat: MistMessage { .updateQueryComponent(component: component, html: html) }
    }

    struct QueryDelete: BroadcastableMessage, SendableMessage {
        let component: String
        var wireFormat: MistMessage { .deleteQueryComponent(component: component) }
    }
    
}
