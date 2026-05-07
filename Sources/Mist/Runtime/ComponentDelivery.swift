import Vapor

extension MistInterface {

    /// Runtime delivery adapter that turns component render outcomes into client-visible effects.
    var delivery: ComponentDelivery { ComponentDelivery(app: app) }

}

/// Executes the Mist component delivery policy through the runtime client registry.
struct ComponentDelivery {

    let app: Application

    enum InstanceMutation: Equatable {
        case create
        case update
    }

    /// Sends the current fragment state to one client.
    func sendCurrentFragment(_ component: any FragmentComponent, to clientID: UUID) async {
        let result = await app.mist.renderer.renderCurrentFragment(component)
        await sendFragmentResult(result, for: component.name, to: clientID)
    }

    /// Broadcasts the current fragment state to subscribers.
    func broadcastCurrentFragment(_ component: any FragmentComponent) async {
        let result = await app.mist.renderer.renderCurrentFragment(component)
        await broadcastFragmentResult(result, for: component.name)
    }

    /// Sends already-rendered fragment HTML to one client.
    func sendFragmentHTML(_ html: String, for component: String, to clientID: UUID) async {
        await app.mist.clients.send(Message.QueryUpdate(component: component, html: html), to: clientID)
    }

    /// Sends a fragment absence to one client.
    func sendFragmentAbsence(for component: String, to clientID: UUID) async {
        await app.mist.clients.send(Message.QueryDelete(component: component), to: clientID)
    }

    /// Broadcasts already-rendered fragment HTML to subscribers.
    func broadcastFragmentHTML(_ html: String, for component: String) async {
        await app.mist.clients.broadcast(Message.QueryUpdate(component: component, html: html))
    }

    /// Sends a fragment render result to one client.
    func sendFragmentResult(_ result: RenderResult, for component: String, to clientID: UUID) async {
        switch result {
        case .rendered(let html):
            await app.mist.clients.send(Message.QueryUpdate(component: component, html: html), to: clientID)
        case .absent:
            await app.mist.clients.send(Message.QueryDelete(component: component), to: clientID)
        case .failed:
            break
        }
    }

    /// Broadcasts a fragment render result to subscribers.
    func broadcastFragmentResult(_ result: RenderResult, for component: String) async {
        switch result {
        case .rendered(let html):
            await app.mist.clients.broadcast(Message.QueryUpdate(component: component, html: html))
        case .absent:
            await app.mist.clients.broadcast(Message.QueryDelete(component: component))
        case .failed:
            break
        }
    }

    /// Delivers a rendered instance create/update to each subscriber with that client's state.
    func deliverInstanceMutation(
        _ mutation: InstanceMutation,
        of component: any InstanceComponent,
        modelID: UUID
    ) async {
        let subscribers = await app.mist.clients.getSubscribers(of: component.name)

        await withTaskGroup(of: Void.self) { group in
            for subscriber in subscribers {
                let clientID = subscriber.clientID

                group.addTask {
                    let state = await self.app.mist.clients.getState(
                        for: clientID,
                        componentID: modelID.uuidString,
                        default: component.defaultState
                    )
                    let result = await self.app.mist.renderer.renderModelComponent(component, modelID: modelID, state: state)
                    guard case .rendered(let html) = result else { return }

                    switch mutation {
                    case .create:
                        let msg = Message.InstanceCreate(component: component.name, modelID: modelID, html: html)
                        await self.app.mist.clients.send(msg, to: clientID)
                    case .update:
                        let msg = Message.InstanceUpdate(component: component.name, modelID: modelID, html: html)
                        await self.app.mist.clients.send(msg, to: clientID)
                    }
                }
            }
        }
    }

    /// Delivers an instance deletion and clears per-instance state for subscribed clients.
    func deliverInstanceDeletion(of component: any InstanceComponent, modelID: UUID) async {
        
        await app.mist.clients.clearState(for: modelID.uuidString, subscribedTo: component.name)
        
        let deleteMessage = Message.InstanceDelete(component: component.name, modelID: modelID)
        await app.mist.clients.broadcast(deleteMessage)
    }

    /// Refreshes one rendered instance after an action successfully mutates per-client state.
    func sendInstanceUpdateAfterAction(
        of component: any Component,
        modelID: UUID?,
        state: ComponentState,
        to clientID: UUID
    ) async {
        guard let modelID else { return }
        guard let component = component as? any InstanceComponent else { return }
        let result = await app.mist.renderer.renderModelComponent(component, modelID: modelID, state: state)
        guard case .rendered(let html) = result else { return }
        
        let updateMessage = Message.InstanceUpdate(component: component.name, modelID: modelID, html: html)
        await app.mist.clients.send(updateMessage, to: clientID)
    }

}
