import Vapor

/// A renderable unit that can be registered and addressed at runtime.
public protocol Component: Sendable {
    
    /// Stable runtime identity for subscriptions, actions, and DOM matching.
    var name: String { get }
    
    /// Template source used when the runtime renders this component.
    var template: any Template { get }
    
    /// Actions this component exposes to the runtime.
    var actions: [any Action] { get }
    
    /// Default per-client state for this component.
    var defaultState: ComponentState { get }
    
}

public extension Component {
    
    /// Default component name derived from the Swift type name.
    var name: String { String(describing: Self.self) }
    
    /// Default template is a file with path matching `name`.
    var template: any Template { LeafTemplate.file(name) }
    
    /// Default: a component exposes no actions.
    var actions: [any Action] { [] }
    
    /// Default: a component starts with empty per-client state.
    var defaultState: ComponentState { [:] }
    
}

public extension Component {
    
    /// Renders the component's template with any encodable context.
    func render<Context: Encodable>(with context: Context, on app: Application) async -> RenderResult {
        do {
            let html = try await template.render(context: context, componentName: name, using: app)
            return .rendered(html)
        } catch {
            let templateType = String(describing: type(of: template))
            app.logger.error("\(MistError.renderFailed(component: name, template: templateType, error))")
            return .failed
        }
    }
    
}

/// Result of attempting to render a component.
public enum RenderResult: Sendable {

    /// Rendering produced HTML successfully.
    case rendered(String)

    /// Rendering is intentionally absent and should be treated as no content.
    case absent

    /// Rendering failed and was already reported through the runtime.
    case failed
    
    /// Extracts rendered HTML from RenderOutcome if available.
    var html: String? { if case let .rendered(html) = self { html } else { nil } }

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
