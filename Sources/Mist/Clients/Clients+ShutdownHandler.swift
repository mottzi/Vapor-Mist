import Vapor

extension Clients {
    
    /// Closes all WebSocket connections before Vapor shuts down the HTTP server.
    struct ShutdownHandler: LifecycleHandler {
                
        func shutdownAsync(_ application: Application) async {
            await application.mist.clients.closeAll()
        }
        
    }
    
    /// Sends a close frame to every connected client and waits up to 5 seconds for their channels to close.
    func closeAll() async {
        let sockets = clients.map { $0.socket }
        guard !sockets.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await withTaskGroup(of: Void.self) { inner in
                    for socket in sockets {
                        inner.addTask {
                            try? await socket.close(code: .goingAway)
                            try? await socket.onClose.get()
                        }
                    }
                }
            }
            group.addTask { try? await Task.sleep(for: .seconds(5)) }
            await group.next()
            group.cancelAll()
        }
    }
    
}
