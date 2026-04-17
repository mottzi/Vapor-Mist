import Vapor

/// Errors reported by the Mist runtime.
public enum MistError: Error, CustomStringConvertible {

    /// A Fluent database query failed unexpectedly.
    /// This is distinct from a record not being found; it indicates a real DB-layer error.
    case databaseFetchFailed(String, Error)

    /// An inbound WebSocket message could not be decoded as a known Mist message type.
    /// Includes a preview of the raw text to aid in diagnosing malformed payloads.
    case messageDecodeFailed(String, Error)

    /// An outbound WebSocket message could not be encoded for transmission.
    /// The affected client will not receive the update.
    case messageEncodeFailed(String, Error)

    /// A component's template failed to render.
    /// The affected component will return `.failed` and no HTML will be sent to clients.
    case renderFailed(component: String, template: String, Error)

    /// A model value could not be encoded for template rendering.
    /// The component render will be incomplete or absent.
    case encodingFailed(String)

    /// A component state value used an unsupported primitive JSON type.
    /// Only the explicit `ComponentValue` primitives are accepted when decoding state.
    case unsupportedComponentValue

    public var description: String {
        switch self {
            case .databaseFetchFailed(let context, let error):
                "Mist: database fetch failed (\(context)) — \(error)"
            
            case .messageDecodeFailed(let preview, let error):
                "Mist: incoming message could not be decoded (preview: \"\(preview.prefix(120))\") — \(error)"
            
            case .messageEncodeFailed(let messageType, let error):
                "Mist: outbound '\(messageType)' message could not be encoded — \(error)"

            case .renderFailed(let component, let template, let error):
                "Mist: render failed (component: '\(component)', template: '\(template)') — \(error)"

            case .encodingFailed(let detail):
                "Mist: model encoding failed — \(detail)"

            case .unsupportedComponentValue:
                "Mist: unsupported component state value — Expected Int, Bool, or String while decoding."
        }
    }

}
