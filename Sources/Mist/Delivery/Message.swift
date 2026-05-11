import Vapor

/// Message exchanged between clients and the runtime over a socket.
enum Message: Codable {
    
    case ping
    case registration(clientID: UUID)

    case subscribe(component: String, ssrReady: Bool)
    case action(component: String, targetID: UUID?, action: String)

    case text(message: String)
    case actionResult(component: String, targetID: UUID?, action: String, result: ActionResult, message: String)

    case createInstanceComponent(component: String, modelID: UUID, html: String)
    case updateInstanceComponent(component: String, modelID: UUID, html: String)
    case deleteInstanceComponent(component: String, modelID: UUID)

    case updateQueryComponent(component: String, html: String)
    case deleteQueryComponent(component: String)

    case replaceStream(component: String, modelID: UUID, stream: String, text: String)
    case appendStream(component: String, modelID: UUID, stream: String, text: String)
    case closeStream(component: String, modelID: UUID, stream: String)

}

/// These wrappers keep `Message` as the single wire format while expressing routing intent in types.
/// A payload can be sendable, broadcastable, or both.
/// This prevents routing a message in unsupported ways at compile time.

protocol SendableMessage {
    var wireFormat: Message { get }
}

protocol BroadcastableMessage {
    var component: String { get }
    var wireFormat: Message { get }
}

extension Message {

    struct Text: SendableMessage {
        let message: String
        var wireFormat: Message { .text(message: message) }
    }

    struct Registration: SendableMessage {
        let clientID: UUID
        var wireFormat: Message { .registration(clientID: clientID) }
    }

    struct ActionResultMessage: SendableMessage {
        let component: String
        let targetID: UUID?
        let action: String
        let result: ActionResult
        let message: String

        var wireFormat: Message { .actionResult(component: component, targetID: targetID, action: action, result: result, message: message) }
    }

}

extension Message {

    struct InstanceCreate: SendableMessage {
        let component: String
        let modelID: UUID
        let html: String
        var wireFormat: Message { .createInstanceComponent(component: component, modelID: modelID, html: html) }
    }

    struct InstanceUpdate: SendableMessage {
        let component: String
        let modelID: UUID
        let html: String
        var wireFormat: Message { .updateInstanceComponent(component: component, modelID: modelID, html: html) }
    }

    struct InstanceDelete: BroadcastableMessage {
        let component: String
        let modelID: UUID
        var wireFormat: Message { .deleteInstanceComponent(component: component, modelID: modelID) }
    }

    struct QueryUpdate: BroadcastableMessage, SendableMessage {
        let component: String
        let html: String
        var wireFormat: Message { .updateQueryComponent(component: component, html: html) }
    }

    struct QueryDelete: BroadcastableMessage, SendableMessage {
        let component: String
        var wireFormat: Message { .deleteQueryComponent(component: component) }
    }

}

extension Message {

    struct StreamReplace: BroadcastableMessage, SendableMessage {
        let component: String
        let modelID: UUID
        let stream: String
        let text: String
        var wireFormat: Message { .replaceStream(component: component, modelID: modelID, stream: stream, text: text) }
    }

    struct StreamAppend: BroadcastableMessage, SendableMessage {
        let component: String
        let modelID: UUID
        let stream: String
        let text: String
        var wireFormat: Message { .appendStream(component: component, modelID: modelID, stream: stream, text: text) }
    }

    struct StreamClose: BroadcastableMessage, SendableMessage {
        let component: String
        let modelID: UUID
        let stream: String
        var wireFormat: Message { .closeStream(component: component, modelID: modelID, stream: stream) }
    }

}
