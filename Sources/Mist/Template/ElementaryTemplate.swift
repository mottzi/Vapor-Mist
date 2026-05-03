import Elementary
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

// MARK: - Direct Vapor Integration

/// A lightweight, thread-safe container that bridges Mist components directly to Vapor,
/// completely bypassing Swift's associated type resolution bugs.
public struct MistResponseView<Content: HTML>: AsyncResponseEncodable, @unchecked Sendable {
    private let content: Content

    public init(_ content: Content) {
        self.content = content
    }

    /// Renders the HTML directly into a Vapor Response without passing through the HTML protocol again.
    public func encodeResponse(for request: Request) async throws -> Response {
        let htmlString = content.render()
        let response = Response(status: .ok, body: .init(string: htmlString))
        response.headers.contentType = .html
        return response
    }
}

// MARK: - Component View Extensions

public extension LiveComponent where Body: HTML {
    /// Derives an Elementary-backed template from `body(state:)` for live components.
    var template: any Template {
        ElementaryTemplate<FragmentState, Body> { [self] state in body(state: state) }
    }

    /// Helper to render the component directly as a Vapor Response.
    func view(state: FragmentState) -> MistResponseView<Body> {
        MistResponseView(self.body(state: state))
    }
}

public extension ManualComponent where Body: HTML {
    /// Derives an Elementary-backed template from `body(state:)` for manual components.
    var template: any Template {
        ElementaryTemplate<FragmentState, Body> { [self] state in body(state: state) }
    }

    /// Helper to render the component directly as a Vapor Response.
    func view(state: FragmentState) -> MistResponseView<Body> {
        MistResponseView(self.body(state: state))
    }
}

public extension PollingComponent where Body: HTML {
    /// Derives an Elementary-backed template from `body(context:)` for polling components.
    var template: any Template {
        ElementaryTemplate<FragmentContext, Body> { [self] context in body(context: context) }
    }

    /// Helper to render the component directly as a Vapor Response.
    func view(context: FragmentContext) -> MistResponseView<Body> {
        MistResponseView(self.body(context: context))
    }
}
