import XCTVapor
import Fluent
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

final class ComponentRendererTests: XCTestCase {
    
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.migrations.add(DummyModel1.Table())
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

}
