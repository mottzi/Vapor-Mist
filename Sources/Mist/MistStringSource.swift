import Vapor
import LeafKit
import NIOCore

/// A thread-safe, in-memory `LeafSource` for production use with Mist components.
///
/// This actor-based source allows components to provide inline template strings instead of
/// requiring file-based templates. It works alongside file-based sources in a prioritized
/// search order, with templates cached by `LeafRenderer` after first parse.
///
/// ## Usage
/// ```swift
/// let stringSource = MistStringSource()
/// await stringSource.register(name: "MyComponent", template: "<div>#(data)</div>")
/// ```
public actor MistStringSource: LeafSource {

    private var templates: [String: String] = [:]

    public init() {}

    /// Register a template string with a given name.
    ///
    /// - Parameters:
    ///   - name: The template identifier (typically the component's `template` property)
    ///   - template: The Leaf template string content
    public func register(name: String, template: String) {
        self.templates[name] = template
    }

    /// Conformance to `LeafSource` protocol.
    ///
    /// Returns the template content as a `ByteBuffer` if found, otherwise fails with
    /// `.noTemplateExists` so `LeafRenderer` can try the next source in the search order.
    public nonisolated func file(
        template: String,
        escape: Bool,
        on eventLoop: any EventLoop
    ) throws -> EventLoopFuture<ByteBuffer> {
        
        // Access isolated state through async context
        let future = eventLoop.makeFutureWithTask {
            // Check if we have this template
            if let content = await self.templates[template] {
                var buffer = ByteBufferAllocator().buffer(capacity: content.utf8.count)
                buffer.writeString(content)
                return buffer
            } else {
                // Not found - fail so renderer tries next source
                throw LeafError(.noTemplateExists(template))
            }
        }
        
        return future
    }

}

