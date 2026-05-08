import Vapor

extension MistInterface {

    var renderer: Renderer { Renderer(app: app) }

}

struct Renderer {

    let app: Application

    func render<Context: Encodable>(_ component: any Component, with context: Context) async -> RenderResult {
        do {
            let html = try await component.template.render(context: context, componentName: component.name, using: app)
            return .rendered(html)
        } catch {
            let templateType = String(describing: type(of: component.template))
            app.logger.error("\(MistError.renderFailed(component: component.name, template: templateType, error))")
            return .failed
        }
    }

    func renderHTML<Context: Encodable>(_ component: any Component, with context: Context) async -> String? {
        let result = await render(component, with: context)
        if case .rendered(let html) = result { return html }
        return nil
    }

    func renderModelComponent(
        _ component: any ModelComponent,
        modelID: UUID,
        state: ComponentState? = nil
    ) async -> RenderResult {
        
        let context: (any Encodable)?
        do {
            if let typedComponent = component as? any TypedModelComponent {
                context = try await typedComponent.makeAnyTemplateContext(using: modelID, state: state, on: app.db)
            } else {
                context = try await component.makeContext(using: modelID, state: state, on: app.db)
            }
        } catch {
            app.logger.error("\(MistError.databaseFetchFailed("\(type(of: component)) id=\(modelID)", error))")
            return .failed
        }
        
        guard let context else { return .absent }
        return await render(component, with: context)
    }

    func renderCurrentFragment(_ component: any FragmentComponent) async -> RenderResult {
        return await component.renderCurrent(app: app)
    }

}
