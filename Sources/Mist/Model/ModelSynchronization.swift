import Vapor
import Fluent

extension MistInterface {

    /// Synchronizes externally-mutated model state with connected clients.
    public var models: ModelSynchronization { ModelSynchronization(app: app) }

}

/// Public adapter for reflecting database changes that happened outside Mist's process.
public struct ModelSynchronization {

    let app: Application

    /// Renders the current model state as an instance upsert for every observing component.
    public func sync<M: Model>(_ model: M.Type, id: UUID) async {

        guard let current = await find(model, id: id) else {
            await delete(model, id: id)
            return
        }

        for instance in await app.mist.components.getInstanceComponents(using: M.self) {
            guard instance.shouldUpdate(for: current) else { continue }
            await app.mist.delivery.deliverInstanceMutation(.create, of: instance, modelID: id)
        }

        await refreshQueries(for: current)
    }

    /// Removes the instance from every observing component and refreshes model-backed fragments.
    public func delete<M: Model>(_ model: M.Type, id: UUID) async {

        for instance in await app.mist.components.getInstanceComponents(using: M.self) {
            await app.mist.delivery.deliverInstanceDeletion(of: instance, modelID: id)
        }

        await refreshQueries(using: M.self)
    }

    /// Fetches a concrete model while logging database failures through Mist's diagnostics.
    private func find<M: Model>(_ model: M.Type, id: UUID) async -> M? {
        do {
            return try await M.find(id, on: app.db)
        } catch {
            app.logger.error("\(MistError.databaseFetchFailed("\(M.self) id=\(id)", error))")
            return nil
        }
    }

    /// Refreshes query components that would react to the provided model event.
    private func refreshQueries<M: Model>(for model: M) async {
        for fragment in await app.mist.components.getQueryComponents(using: M.self) {
            guard fragment.shouldUpdate(for: model) else { continue }
            await app.mist.delivery.broadcastCurrentFragment(fragment)
        }
    }

    /// Refreshes query components when only the deleted model type is still known.
    private func refreshQueries<M: Model>(using model: M.Type) async {
        for fragment in await app.mist.components.getQueryComponents(using: M.self) {
            await app.mist.delivery.broadcastCurrentFragment(fragment)
        }
    }

}
