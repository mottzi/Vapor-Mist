import Vapor
import Fluent

public protocol StateComponent: Component {
    
    associatedtype State: Encodable & Equatable & Sendable

    var state: LiveState<State> { get }
    var interval: Duration { get }

    func observe(app: Application) async
    
}

public extension StateComponent
{
    var models: [any Mist.Model.Type] { [] }
    
    func shouldPause(on app: Application) async -> Bool {
        await app.mist.components.isComponentPaused(name)
    }

    func bootState(app: Application) async {

        await state.boot(
            render: { state in
                let templateName = switch template {
                    case .file(let path): path
                    case .inline: name
                }
                guard let buffer = try? await app.leaf.renderer.render(templateName, state).data
                else { return nil }
                return String(buffer: buffer)
            },
            broadcast: { html in
                await app.mist.clients.broadcast(Message.QueryUpdate(component: name, html: html))
            },
            send: { clientID, html in
                await app.mist.clients.send(Message.QueryUpdate(component: name, html: html), to: clientID)
            }
        )
    }

    func startObserving(app: Application) async {
        await bootState(app: app)
        await observe(app: app)
    }
    
    func sendCurrentState(to clientID: UUID) async {
        await state.sendCurrent(to: clientID)
    }
}

public actor LiveState<State: Equatable & Sendable> {
    
    private var state: State
    private var renderHTML: (@Sendable (State) async -> String?)?
    private var broadcastHTML: (@Sendable (String) async -> Void)?
    private var sendHTML: (@Sendable (UUID, String) async -> Void)?
    
    public init(initialState: State) {
        self.state = initialState
    }

    func boot(
        render: @escaping @Sendable (State) async -> String?,
        broadcast: @escaping @Sendable (String) async -> Void,
        send: @escaping @Sendable (UUID, String) async -> Void
    ) {
        self.renderHTML = render
        self.broadcastHTML = broadcast
        self.sendHTML = send
    }

    public var current: State { state }

    public func set(_ newState: State) async {
        
        guard newState != state else { return }
        state = newState
        
        guard let html = await renderHTML?(state) else { return }
        await broadcastHTML?(html)
    }
    
    func broadcastCurrent() async {
        guard let html = await renderHTML?(state) else { return }
        await broadcastHTML?(html)
    }
    
    public func sendCurrent(to clientID: UUID) async {
        guard let html = await renderHTML?(state) else { return }
        await sendHTML?(clientID, html)
    }
}
