import Vapor

enum Message: Codable
{
    case subscribe(component: String)
    case action(component: String, id: UUID?, action: String)

    case text(message: String)
    case actionResult(component: String, id: UUID?, action: String, result: Mist.ActionResult, message: String)

    case createInstanceComponent(component: String, id: UUID, html: String)
    case updateInstanceComponent(component: String, id: UUID, html: String)
    case deleteInstanceComponent(component: String, id: UUID)

    case updateQueryComponent(component: String, html: String)
    case deleteQueryComponent(component: String)
}

extension Clients
{
    private func send<T: SendableMessage>(message: T, to clientID: UUID)
    {
        guard let client = clients.first(where: { $0.id == clientID }) else { return }
        guard let jsonData = try? JSONEncoder().encode(message.wireFormat) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        client.socket.eventLoop.execute
        {
            client.socket.send(jsonString, promise: nil)
        }
    }
    func send(_ message: String, to clientID: UUID) { send(Message.Text(message: message), to: clientID) }
    func send(_ message: Message.Text, to clientID: UUID) { send(message: message, to: clientID) }
    func send(_ actionResult: Message.ActionResult, to clientID: UUID) { send(message: actionResult, to: clientID) }
    func send(_ create: Message.InstanceCreate, to clientID: UUID) { send(message: create, to: clientID) }
    func send(_ update: Message.InstanceUpdate, to clientID: UUID) { send(message: update, to: clientID) }
}

extension Clients 
{
    private func broadcast<T: BroadcastableMessage>(message: T) 
    {
        guard let jsonData = try? JSONEncoder().encode(message.wireFormat) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let sockets = subscribers(of: message.component).map { $0.socket }

        for socket in sockets 
        {
            socket.eventLoop.execute { socket.send(jsonString, promise: nil) }
        }
    }

    func broadcast(_ create: Message.InstanceCreate) { broadcast(message: create) }
    func broadcast(_ update: Message.InstanceUpdate) { broadcast(message: update) }
    func broadcast(_ delete: Message.InstanceDelete) { broadcast(message: delete) }
    func broadcast(_ update: Message.QueryUpdate) { broadcast(message: update) }
    func broadcast(_ delete: Message.QueryDelete) { broadcast(message: delete) }
}

protocol SendableMessage
{
    var wireFormat: Message { get }
}

protocol BroadcastableMessage
{
    var component: String { get }
    var wireFormat: Message { get }
}

extension Message
{
    struct Text: SendableMessage
    {
        let message: String

        var wireFormat: Message { .text(message: message) }
    }

    struct ActionResult: SendableMessage
    {
        let component: String
        let id: UUID?
        let action: String
        let result: Mist.ActionResult
        let message: String

        var wireFormat: Message { .actionResult(component: component, id: id, action: action, result: result, message: message) }
    }
}

extension Message
{
    struct InstanceCreate: BroadcastableMessage, SendableMessage
    {
        let component: String
        let id: UUID
        let html: String
        var wireFormat: Message { .createInstanceComponent(component: component, id: id, html: html) }
    }

    struct InstanceUpdate: BroadcastableMessage, SendableMessage
    {
        let component: String
        let id: UUID
        let html: String
        var wireFormat: Message { .updateInstanceComponent(component: component, id: id, html: html) }
    }

    struct InstanceDelete: BroadcastableMessage
    {
        let component: String
        let id: UUID
        var wireFormat: Message { .deleteInstanceComponent(component: component, id: id) }
    }

    struct QueryUpdate: BroadcastableMessage
    {
        let component: String
        let html: String
        var wireFormat: Message { .updateQueryComponent(component: component, html: html) }
    }

    struct QueryDelete: BroadcastableMessage
    {
        let component: String
        var wireFormat: Message { .deleteQueryComponent(component: component) }
    }
}
