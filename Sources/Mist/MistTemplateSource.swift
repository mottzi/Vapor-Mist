import Vapor
import LeafKit
import NIOCore

public actor TemplateSource: LeafSource {

    private var templates: [String: String] = [:]

    public init() {}

    public func register(name: String, template: String) {
        self.templates[name] = template
    }
    
    public nonisolated func file(
        template: String,
        escape: Bool,
        on eventLoop: any EventLoop
    ) throws -> EventLoopFuture<ByteBuffer> {
        
        let future = eventLoop.makeFutureWithTask {
            guard let content = await self.templates[template] else { throw LeafError(.noTemplateExists(template)) }
            var buffer = ByteBufferAllocator().buffer(capacity: content.utf8.count)
            buffer.writeString(content)
            return buffer
        }
        
        return future
    }

}

