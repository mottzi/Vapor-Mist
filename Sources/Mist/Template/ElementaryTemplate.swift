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

// MARK: - Unified Mist View Wrapper

/// A unified wrapper that hides the opaque HTML return types for Mist components.
/// It bridges the gap between Elementary's type inference and Vapor's strict concurrency rules,
/// bypassing the `Never` fallback bug and removing the need for `& Sendable` user boilerplate.
public struct MistComponentView<Content: HTML>: HTML, @unchecked Sendable {
    
    // By storing the HTML as the explicit generic parameter `Content`,
    // Swift perfectly satisfies the `associatedtype Content` protocol witness.
    private let _content: Content

    public init(_ content: Content) {
        self._content = content
    }

    public var content: Content {
        _content
    }
}

// MARK: - Component View Extensions

public extension LiveComponent where Body: HTML {
    /// Derives an Elementary-backed template from `body(state:)` for live components.
    var template: any Template {
        ElementaryTemplate<FragmentState, Body> { [self] state in body(state: state) }
    }

    /// Helper to render the component safely in concurrent Vapor routes.
    func view(state: FragmentState) -> MistComponentView<Body> {
        MistComponentView(self.body(state: state))
    }
}

public extension ManualComponent where Body: HTML {
    /// Derives an Elementary-backed template from `body(state:)` for manual components.
    var template: any Template {
        ElementaryTemplate<FragmentState, Body> { [self] state in body(state: state) }
    }

    /// Helper to render the component safely in concurrent Vapor routes.
    func view(state: FragmentState) -> MistComponentView<Body> {
        MistComponentView(self.body(state: state))
    }
}

public extension PollingComponent where Body: HTML {
    /// Derives an Elementary-backed template from `body(context:)` for polling components.
    var template: any Template {
        ElementaryTemplate<FragmentContext, Body> { [self] context in body(context: context) }
    }

    /// Helper to render the component safely in concurrent Vapor routes.
    func view(context: FragmentContext) -> MistComponentView<Body> {
        MistComponentView(self.body(context: context))
    }
}
