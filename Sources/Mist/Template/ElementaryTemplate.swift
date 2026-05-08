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
    
    static func mistComponent(_ value: String) -> HTMLAttribute {
        HTMLAttribute(name: "mist-component", value: value)
    }
    
    static func mistId(_ value: String) -> HTMLAttribute {
        HTMLAttribute(name: "mist-id", value: value)
    }
    
    static func mistAction(_ value: String) -> HTMLAttribute {
        HTMLAttribute(name: "mist-action", value: value)
    }

    static func mistActionsFor(_ component: String) -> HTMLAttribute {
        HTMLAttribute(name: "mist-actions-for", value: component)
    }

    static func mistSSR(_ value: Bool = true) -> HTMLAttribute {
        HTMLAttribute(name: "mist-ssr", value: value ? "true" : "false")
    }

    static func mistContainer(_ acceptedComponents: [String]) -> HTMLAttribute {
        HTMLAttribute(name: "mist-container", value: acceptedComponents.joined(separator: ","))
    }

    static func mistInsertPosition(_ value: String) -> HTMLAttribute {
        HTMLAttribute(name: "mist-insert-position", value: value)
    }

    static func mistBehavior(_ value: String) -> HTMLAttribute {
        HTMLAttribute(name: "mist-behavior", value: value)
    }

    static func mistStream(_ name: String) -> HTMLAttribute {
        HTMLAttribute(name: "mist-stream", value: name)
    }

    static func mistStartedAt(_ date: Date) -> HTMLAttribute {
        let ms = Int64(date.timeIntervalSince1970 * 1000)
        return HTMLAttribute(name: "data-started-at-unix-ms", value: String(ms))
    }

    static func mistSortValue(_ value: CustomStringConvertible) -> HTMLAttribute {
        HTMLAttribute(name: "data-mist-sort-value", value: String(describing: value))
    }

    static func mistSortOrder(_ order: String) -> HTMLAttribute {
        HTMLAttribute(name: "data-mist-sort-order", value: order)
    }

    static func mistSortType(_ type: String) -> HTMLAttribute {
        HTMLAttribute(name: "data-mist-sort-type", value: type)
    }

    static func mistSortDelay(ms: Int) -> HTMLAttribute {
        HTMLAttribute(name: "data-mist-sort-delay-ms", value: String(ms))
    }
    
    static func mistDelay(ms: Int) -> HTMLAttribute {
        HTMLAttribute(name: "mist-delay", value: String(ms))
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

/// Model-backed component rendered by Elementary from a strongly typed context.
public protocol ElementaryModelComponent: TypedModelComponent {

    /// HTML body type returned by the Elementary template.
    associatedtype Body: HTML

    /// Returns this component's HTML body from its template-native context.
    func body(context: TemplateContext) -> Body

}

public extension ElementaryModelComponent {

    var template: any Template {
        ElementaryTemplate<TemplateContext, Body> { [self] context in body(context: context) }
    }

}

/// Instance component rendered by Elementary from a strongly typed context.
public protocol ElementaryInstanceComponent: TypedInstanceComponent, ElementaryModelComponent {}

/// Query component rendered by Elementary from a strongly typed context.
public protocol ElementaryQueryComponent: TypedQueryComponent, ElementaryModelComponent {}
