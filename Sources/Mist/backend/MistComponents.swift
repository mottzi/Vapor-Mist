import Fluent
import Vapor

public actor Components
{
    var components: [any Component] = []
    
    var modelToComponents: [ObjectIdentifier: [any Component]] = [:]
    var componentActions: [String: [String: any Action]] = [:]
    var activeRequests: Set<String> = []

    init() {}
}

extension Components
{
    func registerComponents(_ components: [any Component], with app: Application)
    {
        for component in components
        {
            switch component
            {
                case is InstanceComponent: break
                case is QueryComponent: break
                default:
                    app.logger.warning("Invalid Component '\(component.name)' attempted registration: ignored.")
                    continue
            }

            guard !hasComponent(usingName: component.name) else { continue }

            for model in component.models
            {
                guard !hasComponent(usingModel: model) else { continue }
                model.registerListener(with: app)
            }

            self.components.append(component)

            for model in component.models
            {
                let key = ObjectIdentifier(model)
                modelToComponents[key, default: []].append(component)
            }

            guard !component.actions.isEmpty else { continue }
            componentActions[component.name] = Dictionary(
                uniqueKeysWithValues: component.actions.map { ($0.name, $0) })
        }
    }

    func getComponents<M: Model>(usingModel model: M.Type) -> [any Component]
    {
        let key = ObjectIdentifier(M.self)
        return modelToComponents[key] ?? []
    }

    func getComponent(usingName name: String) -> (any Component)?
    {
        return components.first(where: { $0.name == name })
    }

    func hasComponent(usingName name: String) -> Bool
    {
        return components.contains { $0.name == name }
    }

    func hasComponent(usingModel model: any Model.Type) -> Bool
    {
        let key = ObjectIdentifier(model)
        return modelToComponents[key] != nil
    }

    func performAction(component: String, action: String, id: UUID?, clientID: UUID, clients: MistClients, on db: Database) async -> ActionResult
    {
        // 1. Generate a unique key for this specific UI element for this specific user
        let componentKey = id?.uuidString ?? component
        let lockKey = "\(clientID.uuidString)-\(componentKey)"

        // 2. Check if we are already busy
        guard !activeRequests.contains(lockKey) else { return .failure(message: "Action already in progress") }

        // 3. Lock
        activeRequests.insert(lockKey)

        // 4. Ensure we unlock even if the action crashes or throws
        defer { activeRequests.remove(lockKey) }

        guard let componentActions = componentActions[component] else { return .failure(message: "Component '\(component)' not found") }
        guard let action = componentActions[action] else { return .failure(message: "Action '\(action)' not found") }
        guard let componentInstance = components.first(where: { $0.name == component }) else { return .failure(message: "Component '\(component)' not found") }

        // componentKey is already defined above
        var state = await clients.state(for: clientID, componentID: componentKey, default: componentInstance.defaultState)
        let result = await action.perform(id: id, state: &state, on: db)
        await clients.setState(state, for: clientID, componentID: componentKey)
        return result
    }
}
