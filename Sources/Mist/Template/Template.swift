import Vapor

/// Shared rendering contract for Mist template backends.
public protocol Template: Sendable {

    /// Renders the provided component context into HTML.
    func render<Context: Encodable>(
        context: Context,
        componentName: String,
        using app: Application
    ) async throws -> String

}
