import XCTVapor
import Fluent
import Elementary
@testable import Mist
import XCTest

struct RendererStaticTemplate: Mist.Template {
    let html: String
    func render<Context: Encodable>(context: Context, componentName: String, using app: Application) async throws -> String {
        return html
    }
}

struct RendererThrowingTemplate: Mist.Template {
    struct DummyError: Error {}
    func render<Context: Encodable>(context: Context, componentName: String, using app: Application) async throws -> String {
        throw DummyError()
    }
}

struct TestFragmentComponent: Mist.FragmentComponent {
    let name = "TestFragmentComponent"
    let template: any Mist.Template

    func renderCurrent(app: Application) async -> RenderResult {
        return await app.mist.renderer.render(self, with: ["test": "context"])
    }
}

struct TestModelComponent: Mist.InstanceComponent {
    let name = "TestModelComponent"
    let template: any Mist.Template = RendererStaticTemplate(html: "<div>model component</div>")
    let models: [any Mist.Model.Type] = [DummyModel1.self]
}

struct RendererTypedInstanceContext: Encodable, Equatable {
    let id: UUID
    let primaryText: String
    let secondaryText: String?
    let detailsExpanded: Bool
}

struct RendererElementaryInstanceComponent: Mist.ElementaryInstanceComponent {
    typealias InstanceModel = DummyModel1
    typealias TemplateContext = RendererTypedInstanceContext

    let name = "RendererElementaryInstanceComponent"
    let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
    let defaultState: ComponentState = ["detailsExpanded": .bool(false)]

    func makeTemplateContext(
        from primaryModel: DummyModel1,
        state: ComponentState?,
        on db: Database
    ) async throws -> RendererTypedInstanceContext? {

        guard let id = primaryModel.id else { return nil }
        let secondary = try await DummyModel2.find(id, on: db)

        return RendererTypedInstanceContext(
            id: id,
            primaryText: primaryModel.text,
            secondaryText: secondary?.text2,
            detailsExpanded: state?["detailsExpanded"]?.bool ?? false
        )
    }

    func body(context: RendererTypedInstanceContext) -> some HTML {
        div(.mistComponent(name), .mistId(context.id.uuidString)) {
            span { context.primaryText }
            if let secondaryText = context.secondaryText {
                span { secondaryText }
            }
            span { context.detailsExpanded ? "open" : "closed" }
        }
    }
}

struct RendererTypedQueryContext: Encodable, Equatable {
    let text: String
}

struct RendererElementaryQueryComponent: Mist.ElementaryQueryComponent {
    typealias FragmentModel = DummyModel1
    typealias TemplateContext = RendererTypedQueryContext

    let name = "RendererElementaryQueryComponent"

    func query(on db: Database) async throws -> DummyModel1? {
        try await DummyModel1.query(on: db).first()
    }

    func makeTemplateContext(
        from model: DummyModel1,
        state: ComponentState?,
        on db: Database
    ) async throws -> RendererTypedQueryContext? {
        RendererTypedQueryContext(text: model.text)
    }

    func body(context: RendererTypedQueryContext) -> some HTML {
        div(.mistComponent(name)) {
            span { context.text }
        }
    }
}

final class ComponentRendererTests: XCTestCase {
    
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.migrations.add(DummyModel1.Table(), DummyModel2.Table())
        try await app.autoMigrate()
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
    }

    func testRenderReturnsRenderedHTML() async throws {
        let template = RendererStaticTemplate(html: "<div>Success</div>")
        let component = TestFragmentComponent(template: template)
        
        let result = await app.mist.renderer.render(component, with: ["value": "x"])
        
        if case .rendered(let html) = result {
            XCTAssertEqual(html, "<div>Success</div>")
        } else {
            XCTFail("Expected .rendered, got \(result)")
        }
    }

    func testRenderFailureReturnsFailed() async throws {
        let template = RendererThrowingTemplate()
        let component = TestFragmentComponent(template: template)
        
        let result = await app.mist.renderer.render(component, with: ["value": "x"])
        
        if case .failed = result {
            // expected
        } else {
            XCTFail("Expected .failed, got \(result)")
        }
    }

    func testRenderHTMLReturnsOnlyRenderedHTML() async throws {
        let staticTemplate = RendererStaticTemplate(html: "<div>Success</div>")
        let staticComponent = TestFragmentComponent(template: staticTemplate)
        
        let stringResult = await app.mist.renderer.renderHTML(staticComponent, with: ["value": "x"])
        XCTAssertEqual(stringResult, "<div>Success</div>")
        
        let throwingTemplate = RendererThrowingTemplate()
        let throwingComponent = TestFragmentComponent(template: throwingTemplate)
        
        let nilResult = await app.mist.renderer.renderHTML(throwingComponent, with: ["value": "x"])
        XCTAssertNil(nilResult)
    }

    func testRenderModelReturnsAbsentWhenNoTrackedModelsExist() async throws {
        let component = TestModelComponent()
        
        let result = await app.mist.renderer.renderModelComponent(component, modelID: UUID())
        
        if case .absent = result {
            // expected
        } else {
            XCTFail("Expected .absent, got \(result)")
        }
    }

    func testRenderModelUsesComponentState() async throws {
        // Here we just test it doesn't fail when dummy model exists
        let modelID = UUID()
        let model1 = DummyModel1(id: modelID, text: "test")
        try await model1.create(on: app.db)
        
        let component = TestModelComponent()
        let result = await app.mist.renderer.renderModelComponent(component, modelID: modelID, state: ["key": .string("value")])
        
        if case .rendered(let html) = result {
            XCTAssertEqual(html, "<div>model component</div>")
        } else {
            XCTFail("Expected .rendered, got \(result)")
        }
    }

    func testElementaryInstanceComponentReceivesTypedContext() async throws {
        let modelID = UUID()
        let model1 = DummyModel1(id: modelID, text: "primary")
        let model2 = DummyModel2(id: modelID, text2: "secondary")
        try await model1.create(on: app.db)
        try await model2.create(on: app.db)

        let component = RendererElementaryInstanceComponent()
        let result = await app.mist.renderer.renderModelComponent(
            component,
            modelID: modelID,
            state: ["detailsExpanded": .bool(true)]
        )

        guard case .rendered(let html) = result else {
            return XCTFail("Expected .rendered, got \(result)")
        }

        XCTAssertTrue(html.contains("RendererElementaryInstanceComponent"))
        XCTAssertTrue(html.contains(modelID.uuidString))
        XCTAssertTrue(html.contains("primary"))
        XCTAssertTrue(html.contains("secondary"))
        XCTAssertTrue(html.contains("open"))
    }

    func testTypedInstanceComponentBuildsInitialSSRContexts() async throws {
        let modelID = UUID()
        let model1 = DummyModel1(id: modelID, text: "initial primary")
        let model2 = DummyModel2(id: modelID, text2: "initial secondary")
        try await model1.create(on: app.db)
        try await model2.create(on: app.db)

        let contexts = try await RendererElementaryInstanceComponent().makeTemplateContexts(ofAll: app.db)

        XCTAssertEqual(contexts, [
            RendererTypedInstanceContext(
                id: modelID,
                primaryText: "initial primary",
                secondaryText: "initial secondary",
                detailsExpanded: false
            )
        ])
    }

    func testElementaryQueryComponentReceivesTypedContext() async throws {
        let model = DummyModel1(text: "queried")
        try await model.create(on: app.db)

        let result = await RendererElementaryQueryComponent().renderCurrent(app: app)

        guard case .rendered(let html) = result else {
            return XCTFail("Expected .rendered, got \(result)")
        }

        XCTAssertTrue(html.contains("RendererElementaryQueryComponent"))
        XCTAssertTrue(html.contains("queried"))
    }

}
