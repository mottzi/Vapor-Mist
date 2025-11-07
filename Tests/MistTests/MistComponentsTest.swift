import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import Mist

final class MistComponentsTest: XCTestCase
{    
    // tests integrity of internal component registry and deduplication
    func testInternalStorage() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register multiple components with dublicate
        await app.mist.components.registerComponents([DummyRow1(), DummyRow2(), DummyRow1()], with: app)
        
        // get internal component registry
        let componentsArray = await app.mist.components.components
        
        // verify internal component registry integrity
        XCTAssertEqual(componentsArray.count, 2, "Registry should contain exactly 2 components")
        
        // verify correct internal storage of first component
        XCTAssertEqual(componentsArray[0].name, "DummyRow1", "First component should be 'DummyRow1'")
        XCTAssertEqual(componentsArray[0].models.count, 2, "'DummyRow1' should have 2 models")
        XCTAssertEqual(String(describing: componentsArray[0].models[0]), "DummyModel1", "First model of 'DummyRow1' should be 'DummyModel1'")
        XCTAssertEqual(String(describing: componentsArray[0].models[1]), "DummyModel2", "Second model of 'DummyRow1' should be 'DummyModel2'")

        // verify correct internal storage of second component
        XCTAssertEqual(componentsArray[1].name, "DummyRow2", "Second component should be 'DummyRow2'")
        XCTAssertEqual(componentsArray[1].models.count, 1, "'DummyRow2' should have 1 model")
        XCTAssertEqual(String(describing: componentsArray[1].models[0]), "DummyModel1", "First model of 'DummyRow2' should be 'DummyModel1'")

        try await app.asyncShutdown()
    }
    
    // tests if component lookup by model API returns correct components
    func testLookupByModel() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register multiple components with dublicate
        await app.mist.components.registerComponents([DummyRow1(), DummyRow2(), DummyRow1()], with: app)
        
        // use model-based component lookup API
        let model1Components = await app.mist.components.getComponents(using: DummyModel1.self)
        let model2Components = await app.mist.components.getComponents(using: DummyModel2.self)
        let model3Components = await app.mist.components.getComponents(using: DummyModel3.self)

        // test results of API for first model
        XCTAssertEqual(model1Components.count, 2, "Expected exactly 2 components for DummyModel1")
        XCTAssertEqual(model1Components[0].name, "DummyRow1", "First component should be 'DummyRow1'")
        XCTAssertEqual(model1Components[1].name, "DummyRow2", "Second component should be 'DummyRow2'")
        
        // test results of API for second model
        XCTAssertEqual(model2Components.count, 1, "Expected exactly 1 component for DummyModel2")
        XCTAssertEqual(model2Components[0].name, "DummyRow1", "Only component should be 'DummyRow1'")
        
        // test results of API for third model
        XCTAssertEqual(model3Components.count, 0, "DummyModel3 should not have components")
        
        try await app.asyncShutdown()
    }
    
    // tests that reverse index is correctly maintained during component registration
    func testModelToComponentsReverseIndex() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register components
        await app.mist.components.registerComponents([DummyRow1(), DummyRow2()], with: app)
        
        // test reverse index lookup for DummyModel1 (used by both components)
        let model1Components = await app.mist.components.getComponents(using: DummyModel1.self)
        XCTAssertEqual(model1Components.count, 2, "DummyModel1 should map to 2 components")
        XCTAssertTrue(model1Components.contains(where: { $0.name == "DummyRow1" }))
        XCTAssertTrue(model1Components.contains(where: { $0.name == "DummyRow2" }))
        
        // test reverse index lookup for DummyModel2 (used by one component)
        let model2Components = await app.mist.components.getComponents(using: DummyModel2.self)
        XCTAssertEqual(model2Components.count, 1, "DummyModel2 should map to 1 component")
        XCTAssertEqual(model2Components[0].name, "DummyRow1")
        
        // test non-existent model
        let model3Components = await app.mist.components.getComponents(using: DummyModel3.self)
        XCTAssertEqual(model3Components.count, 0, "Non-registered model should have no components")
        
        try await app.asyncShutdown()
    }
    
    // tests reverse index integrity with direct inspection
    func testReverseIndexIntegrity() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register components
        await app.mist.components.registerComponents([DummyRow1(), DummyRow2()], with: app)
        
        // get reverse index directly
        let reverseIndex = await app.mist.components.modelToComponents
        
        // verify reverse index structure
        XCTAssertEqual(reverseIndex.count, 2, "Reverse index should contain 2 model keys")
        
        // verify DummyModel1 key exists and has correct components
        let model1Key = ObjectIdentifier(DummyModel1.self)
        XCTAssertTrue(reverseIndex.keys.contains(model1Key), "Reverse index should contain DummyModel1 key")
        XCTAssertEqual(reverseIndex[model1Key]?.count, 2, "DummyModel1 should map to 2 components")
        
        // verify DummyModel2 key exists and has correct components
        let model2Key = ObjectIdentifier(DummyModel2.self)
        XCTAssertTrue(reverseIndex.keys.contains(model2Key), "Reverse index should contain DummyModel2 key")
        XCTAssertEqual(reverseIndex[model2Key]?.count, 1, "DummyModel2 should map to 1 component")
        
        // verify DummyModel3 key does not exist
        let model3Key = ObjectIdentifier(DummyModel3.self)
        XCTAssertFalse(reverseIndex.keys.contains(model3Key), "Reverse index should not contain DummyModel3 key")
        
        try await app.asyncShutdown()
    }
    
    // tests that duplicate component registration is prevented and reverse index stays consistent
    func testReverseIndexDeduplication() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register components with duplicate
        await app.mist.components.registerComponents([DummyRow1(), DummyRow2(), DummyRow1()], with: app)
        
        // verify component array has no duplicates
        let componentsArray = await app.mist.components.components
        XCTAssertEqual(componentsArray.count, 2, "Should have only 2 components despite duplicate registration")
        
        // verify reverse index matches deduplicated component array
        let model1Components = await app.mist.components.getComponents(using: DummyModel1.self)
        XCTAssertEqual(model1Components.count, 2, "DummyModel1 should still map to 2 components")
        
        // verify no duplicate entries in reverse index for same component
        let componentNames = model1Components.map { $0.name }
        let uniqueNames = Set(componentNames)
        XCTAssertEqual(componentNames.count, uniqueNames.count, "Reverse index should not contain duplicate component entries")
        
        try await app.asyncShutdown()
    }
    
    // tests that actions are correctly registered for components
    func testActionRegistration() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register components with actions
        await app.mist.components.registerComponents([DummyRowWithActions()], with: app)
        
        // get componentActions index directly
        let componentActions = await app.mist.components.componentActions
        
        // verify component with actions is in the index
        XCTAssertEqual(componentActions.count, 1, "ComponentActions should contain 1 component")
        XCTAssertTrue(componentActions.keys.contains("DummyRowWithActions"), "ComponentActions should contain DummyRowWithActions")
        
        // verify actions are correctly stored
        let actions = componentActions["DummyRowWithActions"]
        XCTAssertNotNil(actions, "DummyRowWithActions should have actions")
        XCTAssertEqual(actions?.count, 2, "DummyRowWithActions should have 2 actions")
        XCTAssertTrue(actions?.keys.contains("testAction") ?? false, "Should contain 'testAction'")
        XCTAssertTrue(actions?.keys.contains("anotherAction") ?? false, "Should contain 'anotherAction'")
        
        try await app.asyncShutdown()
    }
    
    // tests that components without actions are not added to componentActions index
    func testEmptyActionRegistration() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register components without actions
        await app.mist.components.registerComponents([DummyRow1(), DummyRow2()], with: app)
        
        // get componentActions index directly
        let componentActions = await app.mist.components.componentActions
        
        // verify no components in the actions index
        XCTAssertEqual(componentActions.count, 0, "ComponentActions should be empty when no components have actions")
        
        try await app.asyncShutdown()
    }
    
    // tests successful action execution
    func testActionExecution() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // setup test database
        app.migrations.add(DummyModel1.Table())
        try await app.autoMigrate()
        
        // create test model
        let testModel = DummyModel1(text: "test")
        try await testModel.save(on: app.db)
        guard let modelID = testModel.id else {
            XCTFail("Model should have an ID after save")
            return
        }
        
        // register component with actions
        await app.mist.components.registerComponents([DummyRowWithActions()], with: app)
        
        // execute action
        let result = try await app.mist.components.executeAction(
            component: "DummyRowWithActions",
            action: "testAction",
            id: modelID,
            on: app.db
        )
        
        // verify result
        if case .success = result {
            XCTAssertTrue(true, "Action should return success")
        } else {
            XCTFail("Action should return success")
        }
        
        try await app.autoRevert()
        try await app.asyncShutdown()
    }
    
    // tests action execution with non-existent component
    func testActionExecutionInvalidComponent() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register component with actions
        await app.mist.components.registerComponents([DummyRowWithActions()], with: app)
        
        // attempt to execute action on non-existent component
        do {
            _ = try await app.mist.components.executeAction(
                component: "NonExistentComponent",
                action: "testAction",
                id: UUID(),
                on: app.db
            )
            XCTFail("Should throw an error for non-existent component")
        } catch let error as AbortError {
            XCTAssertEqual(error.status, .notFound, "Should throw notFound error")
            XCTAssertTrue(error.reason.contains("NonExistentComponent"), "Error should mention component name")
        } catch {
            XCTFail("Should throw AbortError")
        }
        
        try await app.asyncShutdown()
    }
    
    // tests action execution with non-existent action
    func testActionExecutionInvalidAction() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register component with actions
        await app.mist.components.registerComponents([DummyRowWithActions()], with: app)
        
        // attempt to execute non-existent action
        do {
            _ = try await app.mist.components.executeAction(
                component: "DummyRowWithActions",
                action: "nonExistentAction",
                id: UUID(),
                on: app.db
            )
            XCTFail("Should throw an error for non-existent action")
        } catch let error as AbortError {
            XCTAssertEqual(error.status, .notFound, "Should throw notFound error")
            XCTAssertTrue(error.reason.contains("nonExistentAction"), "Error should mention action name")
        } catch {
            XCTFail("Should throw AbortError")
        }
        
        try await app.asyncShutdown()
    }
    
    // tests reverse index with component that has multiple models
    func testMultipleModelsPerComponent() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register only DummyRow1 which uses 2 models
        await app.mist.components.registerComponents([DummyRow1()], with: app)
        
        // verify both models in reverse index point to same component
        let model1Components = await app.mist.components.getComponents(using: DummyModel1.self)
        let model2Components = await app.mist.components.getComponents(using: DummyModel2.self)
        
        XCTAssertEqual(model1Components.count, 1, "DummyModel1 should map to 1 component")
        XCTAssertEqual(model2Components.count, 1, "DummyModel2 should map to 1 component")
        
        XCTAssertEqual(model1Components[0].name, "DummyRow1")
        XCTAssertEqual(model2Components[0].name, "DummyRow1")
        
        // verify reverse index has entries for both models
        let reverseIndex = await app.mist.components.modelToComponents
        XCTAssertEqual(reverseIndex.count, 2, "Reverse index should have 2 entries for component with 2 models")
        
        try await app.asyncShutdown()
    }
}

struct DummyRow1: Mist.Component
{
    let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
}

struct DummyRow2: Mist.Component
{
    let models: [any Mist.Model.Type] = [DummyModel1.self]
}

struct DummyRowWithActions: Mist.Component
{
    let models: [any Mist.Model.Type] = [DummyModel1.self]
    
    var actions: [any Action]
    {
        return [
            TestAction(),
            AnotherAction()
        ]
    }
}

struct TestAction: Action
{
    let name: String = "testAction"
    
    func execute(id: UUID, on db: Database) async throws -> ActionResult
    {
        return .success
    }
}

struct AnotherAction: Action
{
    let name: String = "anotherAction"
    
    func execute(id: UUID, on db: Database) async throws -> ActionResult
    {
        return .redirect(path: "/test")
    }
}

final class DummyModel1: Mist.Model, Content, @unchecked Sendable
{
    static let schema = "dummymodels"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "text") var text: String
    @Timestamp(key: "created", on: .create) var created: Date?
    
    init() {}
    
    init(id: UUID? = nil, text: String)
    {
        self.id = id
        self.text = text
    }
}

extension DummyModel1
{
    struct Table: AsyncMigration
    {
        func prepare(on database: Database) async throws
        {
            try await database.schema(DummyModel1.schema)
                .id()
                .field("text", .string, .required)
                .field("created", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws
        {
            try await database.schema(DummyModel1.schema).delete()
        }
    }
}

final class DummyModel2: Mist.Model, Content, @unchecked Sendable
{
    static let schema = "dummymodels2"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "text2") var text2: String
    @Timestamp(key: "created", on: .create) var created: Date?
    
    init() {}
    
    init(id: UUID? = nil, text2: String)
    {
        self.id = id
        self.text2 = text2
    }
}

extension DummyModel2
{
    struct Table: AsyncMigration
    {
        func prepare(on database: Database) async throws
        {
            try await database.schema(DummyModel2.schema)
                .id()
                .field("text2", .string, .required)
                .field("created", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws
        {
            try await database.schema(DummyModel2.schema).delete()
        }
    }
}

final class DummyModel3: Mist.Model, Content, @unchecked Sendable
{
    static let schema = "dummymodels3"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "text2") var text3: String
    @Timestamp(key: "created", on: .create) var created: Date?
    
    init() {}
    
    init(text: String)
    {
        self.text3 = text
    }
}
