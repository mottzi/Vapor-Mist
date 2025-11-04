import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import Mist

final class MistComponentsTest: XCTestCase
{
    override func setUp() async throws
    {
        // reset singletons before each test
        await Mist.Clients.shared.resetForTesting()
        await Mist.Components.shared.resetForTesting()
    }
    
    // tests integrity of internal component registry and deduplication
    func testInternalStorage() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register multiple components with dublicate
        let config = Mist.Configuration(for: app, components: [DummyRow1(), DummyRow2(), DummyRow1()])
        await Mist.Components.shared.registerComponents(using: config)
        
        // get internal component registry
        let componentsArray = await Mist.Components.shared.getStorgeForTesting()
        
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
        let config = Mist.Configuration(for: app, components: [DummyRow1(), DummyRow2(), DummyRow1()])
        await Mist.Components.shared.registerComponents(using: config)
        
        // use model-based component lookup API
        let model1Components = await Mist.Components.shared.components(using: DummyModel1.self)
        let model2Components = await Mist.Components.shared.components(using: DummyModel2.self)
        let model3Components = await Mist.Components.shared.components(using: DummyModel3.self)

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
}

struct DummyRow1: Mist.Component
{
    let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
}

struct DummyRow2: Mist.Component
{
    let models: [any Mist.Model.Type] = [DummyModel1.self]
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
