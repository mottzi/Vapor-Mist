import Elementary
import Foundation
import Vapor

/// Typed adapter that renders Mist component contexts with Elementary.
public struct ElementaryTemplate<Context: Encodable, Content: HTML>: Template {

    let body: @Sendable (Context) -> Content

    public init(@HTMLBuilder _ body: @escaping @Sendable (Context) -> Content) {
        self.body = body
    }

    public func render<Provided: Encodable>(
        context: Provided,
        componentName: String,
        using app: Application
    ) async throws -> String {
        guard let typedContext = context as? Context else {
            throw ElementaryError.invalidContext(
                componentName: componentName,
                expected: String(describing: Context.self),
                actual: String(describing: type(of: context))
            )
        }

        return body(typedContext).render()
    }

}

enum ElementaryError: LocalizedError {

    case invalidContext(componentName: String, expected: String, actual: String)

    var errorDescription: String? {
        switch self {
            case .invalidContext(let componentName, let expected, let actual):
                "Mist Elementary template for '\(componentName)' expected \(expected) but received \(actual)."
        }
    }

}

public extension HTMLAttribute where Tag: HTMLTrait.Attributes.Global {
    
    static func mistComponent(value: String) -> HTMLAttribute {
        HTMLAttribute(name: "mist-component", value: value)
    }
    
    static func mistAction(value: String) -> HTMLAttribute {
        HTMLAttribute(name: "mist-action", value: value)
    }
    
}

/// A wrapper that hides the opaque HTML return type for `LiveComponent`, enabling safe rendering in concurrent contexts without `& Sendable` boilerplate.
public struct LiveComponentView<C: LiveComponent>: HTML, Sendable where C.Body: HTML {
    public let component: C
    public let state: C.FragmentState

    public init(_ component: C, state: C.FragmentState) {
        self.component = component
        self.state = state
    }

    public var content: C.Body {
        component.body(state: state)
    }
}

public extension LiveComponent where Body: HTML {

    /// Derives an Elementary-backed template from `body(state:)` for live components.
    var template: any Template {
        ElementaryTemplate<FragmentState, Body> { [self] state in body(state: state) }
    }

    /// Helper to render the component safely in concurrent Vapor routes.
    func view(state: FragmentState) -> LiveComponentView<Self> {
        LiveComponentView(self, state: state)
    }

}

// MARK: - Manual Component View Wrapper

/// A wrapper that hides the opaque HTML return type for `ManualComponent`, enabling safe rendering in concurrent contexts without `& Sendable` boilerplate.
public struct ManualComponentView<C: ManualComponent>: HTML, Sendable where C.Body: HTML {
    public let component: C
    public let state: C.FragmentState

    public init(_ component: C, state: C.FragmentState) {
        self.component = component
        self.state = state
    }

    public var content: C.Body {
        component.body(state: state)
    }
}

public extension ManualComponent where Body: HTML {

    /// Derives an Elementary-backed template from `body(state:)` for manual components.
    var template: any Template {
        ElementaryTemplate<FragmentState, Body> { [self] state in body(state: state) }
    }

    /// Helper to render the component safely in concurrent Vapor routes.
    func view(state: FragmentState) -> ManualComponentView<Self> {
        ManualComponentView(self, state: state)
    }

}

// MARK: - Polling Component View Wrapper

/// A wrapper that hides the opaque HTML return type for `PollingComponent`, enabling safe rendering in concurrent contexts without `& Sendable` boilerplate.
public struct PollingComponentView<C: PollingComponent>: HTML, Sendable where C.Body: HTML {
    public let component: C
    public let context: C.FragmentContext

    public init(_ component: C, context: C.FragmentContext) {
        self.component = component
        self.context = context
    }

    public var content: C.Body {
        component.body(context: context)
    }
}

public extension PollingComponent where Body: HTML {

    /// Derives an Elementary-backed template from `body(context:)` for polling components.
    var template: any Template {
        ElementaryTemplate<FragmentContext, Body> { [self] context in body(context: context) }
    }

    /// Helper to render the component safely in concurrent Vapor routes.
    func view(context: FragmentContext) -> PollingComponentView<Self> {
        PollingComponentView(self, context: context)
    }

}
