import Vapor
import Fluent

// MARK: - ReactiveState Actor

/// A thread-safe, reactive state container that automatically broadcasts UI updates
/// when the encapsulated state changes. This actor serves as the singular source of
/// truth for a `StateComponent`'s mutable state.
///
/// **Mutation and Broadcasting:** When `set(_:)` is called, the actor first verifies
/// that the new state differs from the current state (preventing redundant network traffic).
/// If changed, it invokes the render pipeline and broadcasts the resulting HTML to all
/// subscribed WebSocket clients.
public actor ReactiveState<State: Encodable & Equatable & Sendable>
{
    private var state: State
    private var renderHTML: (@Sendable (State) async -> String?)?
    private var broadcastHTML: (@Sendable (String) async -> Void)?
    private var sendHTML: (@Sendable (UUID, String) async -> Void)?
    
    public init(initialState: State)
    {
        self.state = initialState
    }

    /// Called by the framework during component registration to wire up the
    /// rendering and broadcasting pipelines. The component developer never calls this.
    func boot(
        render: @escaping @Sendable (State) async -> String?,
        broadcast: @escaping @Sendable (String) async -> Void,
        send: @escaping @Sendable (UUID, String) async -> Void
    ) {
        self.renderHTML = render
        self.broadcastHTML = broadcast
        self.sendHTML = send
    }

    /// The current state value.
    public var current: State { state }

    /// Mutate the state. If the new value differs from the current value, the component's
    /// Leaf template is rendered and the resulting HTML is broadcast to all subscribers.
    public func set(_ newState: State) async
    {
        guard newState != state else { return }
        state = newState

        guard let html = await renderHTML?(state) else { return }
        await broadcastHTML?(html)
    }
    
    /// Force a broadcast of the current state without requiring a state change.
    /// Used internally by the framework to push the initial state to newly connected clients.
    func broadcastCurrent() async
    {
        guard let html = await renderHTML?(state) else { return }
        await broadcastHTML?(html)
    }
    
    public func sendCurrent(to clientID: UUID) async
    {
        guard let html = await renderHTML?(state) else { return }
        await sendHTML?(clientID, html)
    }
}

// MARK: - StateComponent Protocol

/// A reactive, push-based component protocol. Implementations define a typed `State`,
/// a `ReactiveState` actor that holds it, and a continuous `observe` loop that queries
/// the world and pushes state updates.
///
/// The framework automatically:
/// - Boots the reactive state actor with render/broadcast closures during registration.
/// - Starts the `observe` loop in a detached background task.
/// - Pauses the observe loop (via `shouldPause`) while user-triggered actions execute.
public protocol StateComponent: Component
{
    associatedtype State: Encodable & Equatable & Sendable

    /// The reactive state actor that holds this component's mutable state.
    var reactiveState: ReactiveState<State> { get }

    /// The interval between observe loop iterations.
    var interval: Duration { get }

    /// The continuous background observation entry point. Implementors should loop,
    /// check `shouldPause`, query the system, and push updates to `reactiveState`.
    func observe(app: Application) async
}

// MARK: - StateComponent Default Implementations

public extension StateComponent
{
    // StateComponents don't use Fluent model observation — they are push-based.
    var models: [any Mist.Model.Type] { [] }

    /// Check the framework's action registry to determine if this component's
    /// background observation should yield. Returns `true` when a user-triggered
    /// action is actively manipulating the state.
    func shouldPause(on app: Application) async -> Bool
    {
        await app.mist.components.isComponentPaused(name)
    }

    /// Called by the framework to wire the reactive state actor to the Leaf renderer
    /// and WebSocket broadcasting system. Component developers do not call this.
    func bootState(app: Application) async
    {
        let componentName = name
        let componentTemplate = template

        await reactiveState.boot(
            render: { @Sendable state in
                let templateName = switch componentTemplate
                {
                    case .file(let path): path
                    case .inline: componentName
                }
                guard let buffer = try? await app.leaf.renderer.render(templateName, state).data
                else { return nil }
                return String(buffer: buffer)
            },
            broadcast: { @Sendable html in
                await app.mist.clients.broadcast(Message.QueryUpdate(component: componentName, html: html))
            },
            send: { @Sendable clientID, html in
                await app.mist.clients.send(Message.QueryUpdate(component: componentName, html: html), to: clientID)
            }
        )
    }

    /// Called by the framework to boot the reactive state and launch the observation loop.
    func startObserving(app: Application) async
    {
        await bootState(app: app)
        await observe(app: app)
    }
    
    func sendCurrentState(to clientID: UUID) async
    {
        await reactiveState.sendCurrent(to: clientID)
    }
}
