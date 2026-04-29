import Vapor

/// Append-only text streams scoped to a component instance.
public actor Streams {

    let app: Application
    
    private var buffers: [StreamKey: String] = [:]

    init(app: Application) {
        self.app = app
    }

    public func replace(component: String, modelID: UUID, stream: String, text: String) async {
        
        let key = StreamKey(
            component: component,
            modelID: modelID,
            stream: stream
        )
        
        buffers[key] = text
        
        let message = Message.StreamReplace(
            component: component,
            modelID: modelID,
            stream: stream,
            text: text
        )
        
        await app.mist.clients.broadcast(message)
    }

    public func append(component: String, modelID: UUID, stream: String, text: String) async {
        
        guard !text.isEmpty else { return }

        let key = StreamKey(
            component: component,
            modelID: modelID,
            stream: stream
        )
        
        buffers[key, default: ""].append(text)
        
        let message = Message.StreamAppend(
            component: component,
            modelID: modelID,
            stream: stream,
            text: text
        )
        
        await app.mist.clients.broadcast(message)
    }

    public func close(component: String, modelID: UUID, stream: String) async {
        
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

private struct StreamKey: Hashable, Sendable {

    let component: String
    let modelID: UUID
    let stream: String

}

private struct StreamSnapshot: Sendable {

    let key: StreamKey
    let text: String

}
