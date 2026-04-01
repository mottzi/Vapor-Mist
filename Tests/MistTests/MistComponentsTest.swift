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
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        await app.mist.components.registerComponents([DummyRow1(), DummyRow2(), DummyRow1()])

        let componentsByName = await app.mist.components.componentsByName

        XCTAssertEqual(componentsByName.count, 2, "Registry should contain exactly 2 components")

        guard let dummyRow1 = componentsByName["DummyRow1"] as? any InstanceComponent,
              let dummyRow2 = componentsByName["DummyRow2"] as? any InstanceComponent else
        {
            return XCTFail("Registered components should be addressable by name")
        }

        XCTAssertEqual(dummyRow1.name, "DummyRow1", "Component should be 'DummyRow1'")
        XCTAssertEqual(dummyRow1.models.count, 2, "'DummyRow1' should have 2 models")
        XCTAssertEqual(String(describing: dummyRow1.models[0]), "DummyModel1", "First model of 'DummyRow1' should be 'DummyModel1'")
        XCTAssertEqual(String(describing: dummyRow1.models[1]), "DummyModel2", "Second model of 'DummyRow1' should be 'DummyModel2'")

        XCTAssertEqual(dummyRow2.name, "DummyRow2", "Component should be 'DummyRow2'")
        XCTAssertEqual(dummyRow2.models.count, 1, "'DummyRow2' should have 1 model")
        XCTAssertEqual(String(describing: dummyRow2.models[0]), "DummyModel1", "First model of 'DummyRow2' should be 'DummyModel1'")

        try await app.asyncShutdown()
    }

    // tests if component lookup by model API returns correct components
    func testLookupByModel() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        await app.mist.components.registerComponents([DummyRow1(), DummyRow2(), DummyRow1()])

        let model1Components = await app.mist.components.getInstanceComponents(using: DummyModel1.self)
        let model2Components = await app.mist.components.getInstanceComponents(using: DummyModel2.self)
        let model3Components = await app.mist.components.getInstanceComponents(using: DummyModel3.self)

        XCTAssertEqual(model1Components.count, 2, "Expected exactly 2 components for DummyModel1")
        XCTAssertEqual(model1Components[0].name, "DummyRow1", "First component should be 'DummyRow1'")
        XCTAssertEqual(model1Components[1].name, "DummyRow2", "Second component should be 'DummyRow2'")

        XCTAssertEqual(model2Components.count, 1, "Expected exactly 1 component for DummyModel2")
        XCTAssertEqual(model2Components[0].name, "DummyRow1", "Only component should be 'DummyRow1'")

        XCTAssertEqual(model3Components.count, 0, "DummyModel3 should not have components")

        try await app.asyncShutdown()
    }

    // tests that reverse index is correctly maintained during component registration
    func testModelToComponentsReverseIndex() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        await app.mist.components.registerComponents([DummyRow1(), DummyRow2()])

        let model1Components = await app.mist.components.getInstanceComponents(using: DummyModel1.self)
        XCTAssertEqual(model1Components.count, 2, "DummyModel1 should map to 2 components")
        XCTAssertTrue(model1Components.contains(where: { $0.name == "DummyRow1" }))
        XCTAssertTrue(model1Components.contains(where: { $0.name == "DummyRow2" }))

        let model2Components = await app.mist.components.getInstanceComponents(using: DummyModel2.self)
        XCTAssertEqual(model2Components.count, 1, "DummyModel2 should map to 1 component")
        XCTAssertEqual(model2Components[0].name, "DummyRow1")

        let model3Components = await app.mist.components.getInstanceComponents(using: DummyModel3.self)
        XCTAssertEqual(model3Components.count, 0, "Non-registered model should have no components")

        try await app.asyncShutdown()
    }

    // tests reverse index integrity with direct inspection
    func testReverseIndexIntegrity() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        await app.mist.components.registerComponents([DummyRow1(), DummyRow2()])

        let reverseIndex = await app.mist.components.modelToInstanceComponents

        XCTAssertEqual(reverseIndex.count, 2, "Reverse index should contain 2 model keys")

        let model1Key = ObjectIdentifier(DummyModel1.self)
        XCTAssertTrue(reverseIndex.keys.contains(model1Key), "Reverse index should contain DummyModel1 key")
        XCTAssertEqual(reverseIndex[model1Key]?.count, 2, "DummyModel1 should map to 2 components")

        let model2Key = ObjectIdentifier(DummyModel2.self)
        XCTAssertTrue(reverseIndex.keys.contains(model2Key), "Reverse index should contain DummyModel2 key")
        XCTAssertEqual(reverseIndex[model2Key]?.count, 1, "DummyModel2 should map to 1 component")

        let model3Key = ObjectIdentifier(DummyModel3.self)
        XCTAssertFalse(reverseIndex.keys.contains(model3Key), "Reverse index should not contain DummyModel3 key")

        try await app.asyncShutdown()
    }

    // tests that duplicate component registration is prevented and reverse index stays consistent
    func testReverseIndexDeduplication() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        await app.mist.components.registerComponents([DummyRow1(), DummyRow2(), DummyRow1()])

        let componentsByName = await app.mist.components.componentsByName
        XCTAssertEqual(componentsByName.count, 2, "Should have only 2 components despite duplicate registration")

        let model1Components = await app.mist.components.getInstanceComponents(using: DummyModel1.self)
        XCTAssertEqual(model1Components.count, 2, "DummyModel1 should still map to 2 components")

        let componentNames = model1Components.map { $0.name }
        let uniqueNames = Set(componentNames)
        XCTAssertEqual(componentNames.count, uniqueNames.count, "Reverse index should not contain duplicate component entries")

        try await app.asyncShutdown()
    }

    // tests that actions are correctly registered for components
    func testActionRegistration() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        await app.mist.components.registerComponents([DummyRowWithActions()])

        let componentActions = await app.mist.components.componentActions

        XCTAssertEqual(componentActions.count, 1, "ComponentActions should contain 1 component")
        XCTAssertTrue(componentActions.keys.contains("DummyRowWithActions"), "ComponentActions should contain DummyRowWithActions")

        let actions = componentActions["DummyRowWithActions"]
        XCTAssertNotNil(actions, "DummyRowWithActions should have actions")
        XCTAssertEqual(actions?.count, 3, "DummyRowWithActions should have 3 actions")
        XCTAssertTrue(actions?.keys.contains("testAction") ?? false, "Should contain 'testAction'")
        XCTAssertTrue(actions?.keys.contains("anotherAction") ?? false, "Should contain 'anotherAction'")
        XCTAssertTrue(actions?.keys.contains("failingAction") ?? false, "Should contain 'failingAction'")

        try await app.asyncShutdown()
    }

    // tests that components without actions are not added to componentActions index
    func testEmptyActionRegistration() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        await app.mist.components.registerComponents([DummyRow1(), DummyRow2()])

        let componentActions = await app.mist.components.componentActions

        XCTAssertEqual(componentActions.count, 0, "ComponentActions should be empty when no components have actions")

        try await app.asyncShutdown()
    }

    // tests successful action execution
    func testActionExecution() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        app.migrations.add(DummyModel1.Table())
        try await app.autoMigrate()

        let testModel = DummyModel1(text: "test")
        try await testModel.save(on: app.db)
        guard let modelID = testModel.id else {
            XCTFail("Model should have an ID after save")
            return
        }

        await app.mist.components.registerComponents([DummyRowWithActions()])

        let result = await app.mist.components.performAction(
            "testAction",
            of: "DummyRowWithActions",
            on: modelID,
            for: UUID()
        )

        if case .success(let message) = result {
            XCTAssertNil(message, "TestAction should return success without a message")
        } else {
            XCTFail("Action should return success")
        }

        try await app.autoRevert()
        try await app.asyncShutdown()
    }

    // tests action execution returns correct associated message values
    func testActionResultMessages() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        app.migrations.add(DummyModel1.Table())
        try await app.autoMigrate()

        let testModel = DummyModel1(text: "test")
        try await testModel.save(on: app.db)
        guard let modelID = testModel.id else {
            XCTFail("Model should have an ID after save")
            return
        }

        await app.mist.components.registerComponents([DummyRowWithActions()])

        let result1 = await app.mist.components.performAction(
            "testAction",
            of: "DummyRowWithActions",
            on: modelID,
            for: UUID()
        )

        if case .success(let message) = result1 {
            XCTAssertNil(message, "testAction should return success with nil message")
        } else {
            XCTFail("testAction should return success")
        }

        let result2 = await app.mist.components.performAction(
            "anotherAction",
            of: "DummyRowWithActions",
            on: modelID,
            for: UUID()
        )

        if case .success(let message) = result2 {
            XCTAssertEqual(message, "Custom success message", "anotherAction should return success with custom message")
        } else {
            XCTFail("anotherAction should return success")
        }

        let result3 = await app.mist.components.performAction(
            "failingAction",
            of: "DummyRowWithActions",
            on: modelID,
            for: UUID()
        )

        if case .failure(let message) = result3 {
            XCTAssertEqual(message, "This action always fails", "failingAction should return failure with custom message")
        } else {
            XCTFail("failingAction should return failure")
        }

        try await app.autoRevert()
        try await app.asyncShutdown()
    }

    // tests action execution with non-existent component
    func testActionExecutionInvalidComponent() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        await app.mist.components.registerComponents([DummyRowWithActions()])

        let result = await app.mist.components.performAction(
            "testAction",
            of: "NonExistentComponent",
            on: UUID(),
            for: UUID()
        )

        if case .failure(let message) = result {
            XCTAssertNotNil(message, "Failure should include a message")
            XCTAssertTrue(message?.contains("NonExistentComponent") ?? false, "Error message should mention component name")
        } else {
            XCTFail("Should return failure for non-existent component")
        }

        try await app.asyncShutdown()
    }

    // tests action execution with non-existent action
    func testActionExecutionInvalidAction() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        await app.mist.components.registerComponents([DummyRowWithActions()])

        let result = await app.mist.components.performAction(
            "nonExistentAction",
            of: "DummyRowWithActions",
            on: UUID(),
            for: UUID()
        )

        if case .failure(let message) = result {
            XCTAssertNotNil(message, "Failure should include a message")
            XCTAssertTrue(message?.contains("nonExistentAction") ?? false, "Error message should mention action name")
        } else {
            XCTFail("Should return failure for non-existent action")
        }

        try await app.asyncShutdown()
    }

    // tests reverse index with component that has multiple models
    func testMultipleModelsPerComponent() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        await app.mist.components.registerComponents([DummyRow1()])

        let model1Components = await app.mist.components.getInstanceComponents(using: DummyModel1.self)
        let model2Components = await app.mist.components.getInstanceComponents(using: DummyModel2.self)

        XCTAssertEqual(model1Components.count, 1, "DummyModel1 should map to 1 component")
        XCTAssertEqual(model2Components.count, 1, "DummyModel2 should map to 1 component")

        XCTAssertEqual(model1Components[0].name, "DummyRow1")
        XCTAssertEqual(model2Components[0].name, "DummyRow1")

        let reverseIndex = await app.mist.components.modelToInstanceComponents
        XCTAssertEqual(reverseIndex.count, 2, "Reverse index should have 2 entries for component with 2 models")

        try await app.asyncShutdown()
    }
}

struct DummyRow1: Mist.InstanceComponent
{
    let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
}

struct DummyRow2: Mist.InstanceComponent
{
    let models: [any Mist.Model.Type] = [DummyModel1.self]
}

struct DummyRowWithActions: Mist.InstanceComponent
{
    let models: [any Mist.Model.Type] = [DummyModel1.self]
    
    var actions: [any Action]
    {
        [
            TestAction(),
            AnotherAction(),
            FailingAction()
        ]
    }
}

struct TestAction: Action
{
    let name: String = "testAction"
    
    func perform(targetID: UUID?, state: inout ComponentState, app: Application) async -> ActionResult
    {
        .success()
    }
}

struct AnotherAction: Action
{
    let name: String = "anotherAction"
    
    func perform(targetID: UUID?, state: inout ComponentState, app: Application) async -> ActionResult
    {
        .success("Custom success message")
    }
}

struct FailingAction: Action
{
    let name: String = "failingAction"
    
    func perform(targetID: UUID?, state: inout ComponentState, app: Application) async -> ActionResult
    {
        .failure("This action always fails")
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
