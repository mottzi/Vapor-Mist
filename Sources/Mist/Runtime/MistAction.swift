import Vapor

/// A function defined by components that can be triggered by the client and run on the server.
public protocol MistAction: Sendable {
    
    /// Runtime name used to invoke this action.
    var name: String { get }
    
    /// The action to perform, optionally scoped to a specific runtime target, exposing mutable per-client state.
    func perform(targetID: UUID?, state: inout MistComponentState, app: Application) async -> MistActionResult
    
}

public extension MistAction {
    
    /// Default action name derived from the Swift type name.
    var name: String { String(describing: Self.self) }
    
}

/// Outcome reported back after performing an action.
public enum MistActionResult: Codable, Sendable {
    
    /// The action completed successfully.
    case success(_ message: String? = nil)
    
    /// The action could not be completed.
    case failure(_ message: String? = nil)
    
}
