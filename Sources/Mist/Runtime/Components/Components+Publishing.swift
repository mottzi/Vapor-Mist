import Vapor

extension Components {
    
    /// Starts runtime publishing for a component if needed.
    func startPublishing(for component: any Component) async -> Task<Void, Never>? {
        
        switch component {
        case let component as any ManualComponent: await startManualPublishing(for: component)
        case let component as any LiveComponent: await startLivePublishing(for: component)
        case let component as any PollingComponent: startPollingPublishing(for: component)
        default: nil
        }
    }
    
    /// Starts runtime publishing for a manual component.
    /// Manual components publish only when application code pushes new state into their runtime store.
    func startManualPublishing<C: ManualComponent>(for component: C) async -> Task<Void, Never>? {
        let app = self.app
        
        await component.state.boot(
            render: { state in
                guard case .rendered(let html) = await component.render(with: state, on: app) else { return nil }
                return html
            },
            broadcast: { html in
                await app.mist.clients.broadcast(Message.QueryUpdate(component: component.name, html: html))
            }
        )
        
        return nil
    }
    
    /// Starts runtime publishing for a live component.
    /// Live components own mutable runtime state and refresh that state on a schedule before broadcasting it.
    func startLivePublishing<C: LiveComponent>(for component: C) async -> Task<Void, Never> {
        let app = self.app
        
        await component.state.boot(
            render: { state in
                guard case .rendered(let html) = await component.render(with: state, on: app) else { return nil }
                return html
            },
            broadcast: { html in
                await app.mist.clients.broadcast(Message.QueryUpdate(component: component.name, html: html))
            }
        )
        
        return Task { [app] in
            await component.refresh(app: app)
            
            while !app.didShutdown && !Task.isCancelled {
                try? await Task.sleep(for: component.refreshInterval)
                guard !app.didShutdown && !Task.isCancelled else { break }
                guard await !app.mist.components.areUpdatesSuspended(for: component.name) else { continue }
                await component.refresh(app: app)
            }
        }
    }
    
    /// Starts runtime publishing for a polling component.
    /// Polling components derive their current fragment from repeated source reads rather than retained live state.
    func startPollingPublishing<C: PollingComponent>(for component: C) -> Task<Void, Never> {
        let app = self.app
        
        func tick(lastContext: C.FragmentContext?) async -> C.FragmentContext? {
            guard !app.didShutdown && !Task.isCancelled else { return lastContext }
            
            guard let context = await component.poll(on: app.db) else {
                await app.mist.components.setPollingState(.absent, for: component.name)
                guard lastContext != nil else { return nil }
                await app.mist.clients.broadcast(Message.QueryDelete(component: component.name))
                return nil
            }
            
            guard context != lastContext else { return lastContext }
            
            switch await component.render(with: context, on: app) {
            case .rendered(let html):
                await app.mist.components.setPollingState(.rendered(html), for: component.name)
                await app.mist.clients.broadcast(Message.QueryUpdate(component: component.name, html: html))
                return context
            case .absent, .failed:
                return lastContext
            }
        }
        
        let startupTask = Task<C.FragmentContext?, Never> {
            await tick(lastContext: nil)
        }
        let startupBarrier = Task<Void, Never> {
            _ = await startupTask.value
        }
        pollingState[component.name] = .pending(startupBarrier)
        
        return Task { [app] in
            var lastContext = await startupTask.value
            
            while !app.didShutdown && !Task.isCancelled {
                try? await Task.sleep(for: component.refreshInterval)
                guard !app.didShutdown && !Task.isCancelled else { return }
                lastContext = await tick(lastContext: lastContext)
            }
        }
    }
}

extension Components {
    
    /// Delivery snapshot exposed to new polling subscribers while the polling loop is booting or settled.
    enum PollingDeliveryState {
        
        /// The first polling pass is still establishing the initial deliverable state.
        case pending(Task<Void, Never>)
        
        /// The component currently has no fragment to show.
        case absent
        
        /// The component has settled on rendered HTML ready to send to subscribers.
        case rendered(String)
        
    }
    
    /// Sends cached polling output to a subscriber when the polling runtime already owns the current state.
    func sendPollingStateIfAvailable(for componentName: String, to clientID: UUID) async -> Bool {
        
        guard let state = pollingState[componentName] else { return false }
        
        switch state {
            case .pending(let task):
                await task.value
                return await sendPollingStateIfAvailable(for: componentName, to: clientID)
                
            case .rendered(let html):
                await app.mist.clients.send(Message.QueryUpdate(component: componentName, html: html), to: clientID)
                return true
                
            case .absent:
                await app.mist.clients.send(Message.QueryDelete(component: componentName), to: clientID)
                return true
        }
    }
    
    /// Replaces the polling delivery state observed by future subscribers.
    func setPollingState(_ state: PollingDeliveryState, for component: String) {
        pollingState[component] = state
    }
    
}

/// Lifecycle handler for runtime tasks, cancelling them on app shutdown.
struct TaskLifecycleHandler: LifecycleHandler {
    
    let task: Task<Void, Never>

    func shutdown(_ app: Application) {
        task.cancel()
    }
    
}
