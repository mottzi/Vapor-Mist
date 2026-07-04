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

struct RendererElementaryInstanceComponent: Mist.InstanceComponent {
    let name = "RendererElementaryInstanceComponent"
    let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
    let defaultState: ComponentState = ["detailsExpanded": .bool(false)]

    var template: any Mist.Template {
        ElementaryTemplate<ComponentContext, _> { [self] context in body(context: context) }
    }

    func body(context: ComponentContext) -> some HTML {
        let primary = context.model(DummyModel1.self)!
        let secondary = context.model(DummyModel2.self)
        let detailsExpanded = context.state["detailsExpanded"]?.bool ?? false
        
        return div(.mistComponent(name), .mistId(primary.id!.uuidString)) {
            span { primary.text }
            if let secondary {
                span { secondary.text2 }
            }
            span { detailsExpanded ? "open" : "closed" }
        }
    }
}

struct RendererElementaryQueryComponent: Mist.QueryComponent {
    typealias FragmentModel = DummyModel1
    let name = "RendererElementaryQueryComponent"

    func query(on db: Database) async throws -> DummyModel1? {
        try await DummyModel1.query(on: db).first()
    }

    var template: any Mist.Template {
        ElementaryTemplate<ComponentContext, _> { [self] context in body(context: context) }
    }

    func body(context: ComponentContext) -> some HTML {
        let primary = context.model(DummyModel1.self)!
        return div(.mistComponent(name)) {
            span { primary.text }
        }
    }
}

struct RendererElementaryManualComponent: Mist.ClientStateManualComponent {
    let name = "RendererElementaryManualComponent"
    let state = LiveState(of: true)
    let defaultState: ComponentState = ["expanded": .bool(false)]

    func body(state: Bool) -> some HTML {
        body(state: state, clientState: defaultState)
    }

    func body(state: Bool, clientState: ComponentState) -> some HTML {
        let expanded = clientState["expanded"]?.bool ?? false

        return div(.mistComponent(name)) {
            span { state ? "ready" : "idle" }
            span { expanded ? "expanded" : "collapsed" }
        }
    }

    func renderClientState(app: Application, state componentState: ComponentState) async -> RenderResult {
        let current = await state.current
        return .rendered(body(state: current, clientState: componentState).render())
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
        } else {
            XCTFail("Expected .absent, got \(result)")
        }
    }

    func testRenderModelUsesComponentState() async throws {
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

    func testElementaryInstanceComponentReceivesComponentContext() async throws {
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

    func testElementaryQueryComponentReceivesComponentContext() async throws {
        let model = DummyModel1(text: "queried")
        try await model.create(on: app.db)

        let result = await RendererElementaryQueryComponent().renderCurrent(app: app)

        guard case .rendered(let html) = result else {
            return XCTFail("Expected .rendered, got \(result)")
        }

        XCTAssertTrue(html.contains("RendererElementaryQueryComponent"))
        XCTAssertTrue(html.contains("queried"))
    }

    func testElementaryManualComponentReceivesComponentState() async throws {
        let result = await app.mist.renderer.renderCurrentFragment(
            RendererElementaryManualComponent(),
            state: ["expanded": .bool(true)]
        )

        guard case .rendered(let html) = result else {
            return XCTFail("Expected .rendered, got \(result)")
        }

        XCTAssertTrue(html.contains("RendererElementaryManualComponent"))
        XCTAssertTrue(html.contains("ready"))
        XCTAssertTrue(html.contains("expanded"))
    }

}
