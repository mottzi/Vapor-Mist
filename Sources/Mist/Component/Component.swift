import Vapor

/// A renderable unit that can be registered and addressed at runtime.
public protocol Component: Sendable {
    
    /// Stable runtime identity for subscriptions, actions, and DOM matching.
    var name: String { get }
    
    /// Template source used when the runtime renders this component.
    var template: Template { get }
    
    /// Actions this component exposes to the runtime.
    var actions: [any Action] { get }
    
    /// Default per-client state for this component.
    var defaultState: ComponentState { get }
    
}

public extension Component {
    
    /// Default component name derived from the Swift type name.
    var name: String { String(describing: Self.self) }
    
    /// Default template is a file with path matching `name`.
    var template: Template { .file(path: name) }
    
    /// Default: a component exposes no actions.
    var actions: [any Action] { [] }
    
    /// Default: a component starts with empty per-client state.
    var defaultState: ComponentState { [:] }
    
}

public extension Component {
    
    /// Renders the component's template with any encodable context.
    func render<Context: Encodable>(with context: Context, using renderer: ViewRenderer) async -> String? {
        
        let templateName = switch template {
            case .file(let path): path
            case .inline: name
        }

        guard let buffer = try? await renderer.render(templateName, context).data else { return nil }
        return String(buffer: buffer)
    }
    
}

@resultBuilder
/// Used by `app.mist.use` to restrict registerable component types.
public struct ComponentBuilder {

    public static func buildBlock(_ components: [any Component]...) -> [any Component] { components.flatMap { $0 } }
    
    public static func buildExpression(_ component: any InstanceComponent) -> [any Component] { [component] }
    public static func buildExpression(_ component: any LiveComponent)     -> [any Component] { [component] }
    public static func buildExpression(_ component: any ManualComponent)   -> [any Component] { [component] }
    public static func buildExpression(_ component: any PollingComponent)  -> [any Component] { [component] }
    public static func buildExpression(_ component: any QueryComponent)    -> [any Component] { [component] }

    public static func buildOptional(_    components: [any Component]?)  -> [any Component] { components ?? [] }
    public static func buildEither(first  components: [any Component])   -> [any Component] { components }
    public static func buildEither(second components: [any Component])   -> [any Component] { components }
    public static func buildArray(_       components: [[any Component]]) -> [any Component] { components.flatMap { $0 } }
    
}
