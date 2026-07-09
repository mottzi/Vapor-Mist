import Vapor

extension MistInterface {

    /// Runtime delivery adapter that turns component render outcomes into client-visible effects.
    var delivery: Delivery { Delivery(app: app) }

}

/// Executes the Mist component delivery policy through the runtime client registry.
struct Delivery {

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

    /// Refreshes one rendered fragment after an action successfully mutates per-client state.
    func sendFragmentUpdateAfterAction(
        of component: any Component,
        state: ComponentState,
        to clientID: UUID
    ) async {
        guard let component = component as? any FragmentComponent else { return }
        let result = await app.mist.renderer.renderCurrentFragment(component, state: state)
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

    /// Reconciles a single client's view of an `InstanceComponent` against the server's current state.
    ///
    /// Used during the resubscribe handshake after a WebSocket reconnect. The client reports the
    /// `mist-id`s currently in its DOM as `knownIDs`. This method enumerates `allModels(on:)`,
    /// computes the diff against `knownIDs`, and sends per-instance messages to that one client:
    /// - `deleteInstanceComponent` for IDs in `knownIDs` but no longer on the server.
    /// - `updateInstanceComponent` for IDs in both sets (re-renders with `defaultState`).
    /// - `createInstanceComponent` for IDs on the server but missing from `knownIDs`.
    ///
    /// Per-client `ComponentState` is not preserved across reconnects (the `clientID` rotates),
    /// so renders use `defaultState`.
    func rehydrateInstanceComponent(
        _ component: any InstanceComponent,
        knownIDs: [UUID],
        to clientID: UUID
    ) async {

        let knownSet = Set(knownIDs)

        let models: [any Model]
        do {
            models = try await component.allModels(on: app.db)
        } catch {
            app.logger.error("\(MistError.databaseFetchFailed("\(component.name).allModels", error))")
            return
        }

        var serverIDs: [UUID] = []
        serverIDs.reserveCapacity(models.count)
        for model in models {
            guard let id = model.id else { continue }
            serverIDs.append(id)
        }
        let serverSet = Set(serverIDs)

        // 1. Emit deletes for IDs the client has but the server no longer has.
        for staleID in knownSet.subtracting(serverSet) {
            let message = Message.InstanceDelete(component: component.name, modelID: staleID)
            await app.mist.clients.send(message, to: clientID)
        }

        // 2 & 3. Emit updates for the intersection, creates for IDs the server has but the client lacks.
        for id in serverIDs {
            let result = await app.mist.renderer.renderModelComponent(
                component,
                modelID: id,
                state: component.defaultState
            )
            guard case .rendered(let html) = result else { continue }

            if knownSet.contains(id) {
                let message = Message.InstanceUpdate(component: component.name, modelID: id, html: html)
                await app.mist.clients.send(message, to: clientID)
            } else {
                let message = Message.InstanceCreate(component: component.name, modelID: id, html: html)
                await app.mist.clients.send(message, to: clientID)
            }
        }
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
