import Vapor

/// Stable identity for a component-level stream that is not tied to a model instance.
public struct StaticStream: Sendable, Hashable {

    public let component: String
    public let stream: String

    public init(component: String, stream: String) {
        self.component = component
        self.stream = stream
    }

}

/// Append-only text streams scoped to a component instance.
public actor Streams {

    let app: Application
    
    init(app: Application) {
        self.app = app
    }
    
    private var buffers: [StreamKey: String] = [:]
    private var limits: [StreamKey: StreamLimit] = [:]
    private var staticLifecycles: [StaticStream: StreamLifecycle] = [:]
    private var activeComponents: Set<String> = []

    @discardableResult
    public func staticStream(
        component: String,
        stream: String,
        retainingLines lineLimit: Int? = nil,
        maxBytes: Int = 1_048_576,
        onActive: (@Sendable () async -> Void)? = nil,
        onInactive: (@Sendable () async -> Void)? = nil
    ) -> StaticStream {

        let staticStream = StaticStream(component: component, stream: stream)
        let key = StreamKey(component: component, modelID: nil, stream: stream)

        limits[key] = StreamLimit(lineLimit: lineLimit, byteLimit: maxBytes)

        if onActive != nil || onInactive != nil {
            staticLifecycles[staticStream] = StreamLifecycle(
                onActive: onActive,
                onInactive: onInactive
            )
        }

        return staticStream
    }

    public func replace(_ staticStream: StaticStream, text: String) async {
        await replaceInternal(component: staticStream.component, modelID: nil, stream: staticStream.stream, text: text)
    }

    public func append(_ staticStream: StaticStream, text: String) async {
        await appendInternal(component: staticStream.component, modelID: nil, stream: staticStream.stream, text: text)
    }

    public func close(_ staticStream: StaticStream) async {
        await closeInternal(component: staticStream.component, modelID: nil, stream: staticStream.stream)
    }

    func updateSubscriberCount(for component: String, to count: Int) async {

        let wasActive = activeComponents.contains(component)
        let isActive = count > 0

        guard wasActive != isActive else { return }

        if isActive {
            activeComponents.insert(component)
        } else {
            activeComponents.remove(component)
        }

        let lifecycles = staticLifecycles
            .filter { $0.key.component == component }
            .map(\.value)

        for lifecycle in lifecycles {
            if isActive {
                await lifecycle.onActive?()
            } else {
                await lifecycle.onInactive?()
            }
        }
    }

    public func replace(component: String, modelID: UUID, stream: String, text: String) async {

        await replaceInternal(component: component, modelID: modelID, stream: stream, text: text)
    }

    private func replaceInternal(component: String, modelID: UUID?, stream: String, text: String) async {
        
        let key = StreamKey(
            component: component,
            modelID: modelID,
            stream: stream
        )
        
        buffers[key] = applyLimit(to: text, for: key)
        
        let message = Message.StreamReplace(
            component: component,
            modelID: modelID,
            stream: stream,
            text: buffers[key] ?? ""
        )
        
        await app.mist.clients.broadcast(message)
    }

    public func append(component: String, modelID: UUID, stream: String, text: String) async {

        await appendInternal(component: component, modelID: modelID, stream: stream, text: text)
    }

    private func appendInternal(component: String, modelID: UUID?, stream: String, text: String) async {
        
        guard !text.isEmpty else { return }

        let key = StreamKey(
            component: component,
            modelID: modelID,
            stream: stream
        )
        
        buffers[key, default: ""].append(text)
        buffers[key] = applyLimit(to: buffers[key] ?? "", for: key)
        
        let message = Message.StreamAppend(
            component: component,
            modelID: modelID,
            stream: stream,
            text: text
        )
        
        await app.mist.clients.broadcast(message)
    }

    public func close(component: String, modelID: UUID, stream: String) async {

        await closeInternal(component: component, modelID: modelID, stream: stream)
    }

    private func closeInternal(component: String, modelID: UUID?, stream: String) async {
        
        let key = StreamKey(
            component: component,
            modelID: modelID,
            stream: stream
        )
        
        buffers[key] = nil
        
        let message = Message.StreamClose(
            component: component,
            modelID: modelID,
            stream: stream
        )
        
        await app.mist.clients.broadcast(message)
    }

    func sendSnapshots(for component: String, to clientID: UUID) async {
        
        let snapshots = buffers.compactMap { key, text -> StreamSnapshot? in
            
            guard key.component == component else { return nil }
            
            return StreamSnapshot(
                key: key,
                text: text
            )
        }

        for snapshot in snapshots {
            
            let message = Message.StreamReplace(
                component: snapshot.key.component,
                modelID: snapshot.key.modelID,
                stream: snapshot.key.stream,
                text: snapshot.text
            )

            await app.mist.clients.send(message, to: clientID)
        }
    }

}

private extension Streams {

    func applyLimit(to text: String, for key: StreamKey) -> String {
        guard let limit = limits[key] else { return text }
        return limit.apply(to: text)
    }

}

private struct StreamKey: Hashable, Sendable {

    let component: String
    let modelID: UUID?
    let stream: String

}

private struct StreamSnapshot: Sendable {

    let key: StreamKey
    let text: String

}

private struct StreamLifecycle: Sendable {

    let onActive: (@Sendable () async -> Void)?
    let onInactive: (@Sendable () async -> Void)?

}

private struct StreamLimit: Sendable {

    let lineLimit: Int?
    let byteLimit: Int

    func apply(to text: String) -> String {
        var limited = applyLineLimit(to: text)
        limited = applyByteLimit(to: limited)
        return limited
    }

    private func applyLineLimit(to text: String) -> String {

        guard let lineLimit, lineLimit > 0 else { return text }

        let pieces = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let maximumPieceCount = text.hasSuffix("\n") ? lineLimit + 1 : lineLimit

        guard pieces.count > maximumPieceCount else { return text }
        return pieces.suffix(maximumPieceCount).joined(separator: "\n")
    }

    private func applyByteLimit(to text: String) -> String {

        guard byteLimit > 0 else { return "" }
        guard text.utf8.count > byteLimit else { return text }

        var limited = String(text.suffix(byteLimit))
        while limited.utf8.count > byteLimit, !limited.isEmpty {
            limited.removeFirst()
        }
        return limited
    }

}
