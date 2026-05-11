import Vapor

extension Clients {

    /// Encodes and sends a typed socket message to one client.
    private func send<T: SendableMessage>(message: T, to clientID: UUID) {
        do {
            let jsonData = try JSONEncoder().encode(message.wireFormat)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            
            guard let client = clients.first(where: { $0.clientID == clientID }) else { return }
            client.socket.eventLoop.execute {
                client.socket.send(jsonString, promise: nil)
            }
        } catch {
            logger.error("\(MistError.messageEncodeFailed("\(T.self)", error))")
        }
    }

    func send(_ message: String, to clientID: UUID)                { send(Message.Text(message: message), to: clientID) }
    func send(_ registration: Message.Registration, to clientID: UUID) { send(message: registration, to: clientID) }
    func send(_ message: Message.Text, to clientID: UUID)          { send(message: message, to: clientID) }
    func send(_ actionResult: Message.ActionResultMessage, to clientID: UUID) { send(message: actionResult, to: clientID) }
    func send(_ create: Message.InstanceCreate, to clientID: UUID) { send(message: create, to: clientID) }
    func send(_ update: Message.InstanceUpdate, to clientID: UUID) { send(message: update, to: clientID) }
    func send(_ update: Message.QueryUpdate, to clientID: UUID)    { send(message: update, to: clientID) }
    func send(_ delete: Message.QueryDelete, to clientID: UUID)    { send(message: delete, to: clientID) }
    func send(_ replace: Message.StreamReplace, to clientID: UUID) { send(message: replace, to: clientID) }
    func send(_ append: Message.StreamAppend, to clientID: UUID)   { send(message: append, to: clientID) }
    func send(_ close: Message.StreamClose, to clientID: UUID)     { send(message: close, to: clientID) }

}

extension Clients {

    /// Encodes and broadcasts a typed socket message to all subscribers of a component.
    private func broadcast<T: BroadcastableMessage>(message: T) {

        do {
            let jsonData = try JSONEncoder().encode(message.wireFormat)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            
            let sockets = getSubscribers(of: message.component).map { $0.socket }
            for socket in sockets { socket.eventLoop.execute {
                socket.send(jsonString, promise: nil) }
            }
        } catch {
            logger.error("\(MistError.messageEncodeFailed("\(T.self)", error))")
        }
    }

    func broadcast(_ delete: Message.InstanceDelete) { broadcast(message: delete) }
    func broadcast(_ update: Message.QueryUpdate)    { broadcast(message: update) }
    func broadcast(_ delete: Message.QueryDelete)    { broadcast(message: delete) }
    func broadcast(_ replace: Message.StreamReplace) { broadcast(message: replace) }
    func broadcast(_ append: Message.StreamAppend)   { broadcast(message: append) }
    func broadcast(_ close: Message.StreamClose)     { broadcast(message: close) }

}
