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
    
}

/// Derives an Elementary-backed template from `body(state:)` for live components.
public extension LiveComponent where Body: HTML {

    var template: any Template {
        ElementaryTemplate<FragmentState, Body> { [self] state in body(state: state) }
    }

}

/// Derives an Elementary-backed template from `body(state:)` for manual components.
public extension ManualComponent where Body: HTML {

    var template: any Template {
        ElementaryTemplate<FragmentState, Body> { [self] state in body(state: state) }
    }

}

/// Derives an Elementary-backed template from `body(context:)` for polling components.
public extension PollingComponent where Body: HTML {

    var template: any Template {
        ElementaryTemplate<FragmentContext, Body> { [self] context in body(context: context) }
    }

}
