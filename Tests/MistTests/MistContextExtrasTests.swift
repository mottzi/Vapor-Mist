import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import Mist

final class TestModelWithExtras: Mist.Model, Content, @unchecked Sendable
{
    static let schema = "test_models_with_extras"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "name") var name: String
    @Field(key: "count") var count: Int
    @Timestamp(key: "created", on: .create) var created: Date?
    
    init() {}
    
    init(id: UUID? = nil, name: String, count: Int)
    {
        self.id = id
        self.name = name
        self.count = count
    }
    
    func contextExtras() -> [String: any Encodable]
    {
        return [
            "extraString": "computed value",
            "extraInt": 42,
            "extraArray": ["first", "second", "third"],
            "extraBool": true,
            "extraDouble": 3.14
        ]
    }
}

extension TestModelWithExtras
{
    struct Table: AsyncMigration
    {
        func prepare(on database: Database) async throws
        {
            try await database.schema(TestModelWithExtras.schema)
                .id()
                .field("name", .string, .required)
                .field("count", .int, .required)
                .field("created", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws
        {
            try await database.schema(TestModelWithExtras.schema).delete()
        }
    }
}

final class MistContextExtrasTests: XCTestCase
{
    func testModelWithExtrasEncoding() async throws
    {
        // Set up application and database
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // Add migrations
        app.migrations.add(TestModelWithExtras.Table())
        try await app.autoMigrate()
        
        // Start the server
        try await app.startup()
        
        // Create a test model with a fixed UUID
        guard let modelID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890") else
        {
            return XCTFail("Could not create UUID")
        }
        
        let model = TestModelWithExtras(id: modelID, name: "Test Model", count: 100)
        try await model.save(on: app.db)
        
        // Create a ModelContainer and add the model
        var container = ModelContainer()
        container.add(model, for: "testmodel")
        
        // Encode the container to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let jsonData = try? encoder.encode(container),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else
        {
            return XCTFail("Could not encode ModelContainer to JSON")
        }
        
        print("Encoded JSON:\n\(jsonString)")
        
        // Decode to dictionary for assertions
        guard let decoded = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let testModel = decoded["testmodel"] as? [String: Any]
        else
        {
            return XCTFail("Could not decode JSON to dictionary")
        }
        
        // Verify base model properties
        XCTAssertEqual(testModel["id"] as? String, "A1B2C3D4-E5F6-7890-ABCD-EF1234567890", "Model ID should match")
        XCTAssertEqual(testModel["name"] as? String, "Test Model", "Model name should match")
        XCTAssertEqual(testModel["count"] as? Int, 100, "Model count should match")
        XCTAssertNotNil(testModel["created"], "Model created timestamp should exist")
        
        // Verify extra properties - String
        XCTAssertEqual(testModel["extraString"] as? String, "computed value", "extraString should be present and correct")
        
        // Verify extra properties - Int
        XCTAssertEqual(testModel["extraInt"] as? Int, 42, "extraInt should be present and correct")
        
        // Verify extra properties - Array
        guard let extraArray = testModel["extraArray"] as? [String] else
        {
            return XCTFail("extraArray should be present and be an array of strings")
        }
        XCTAssertEqual(extraArray.count, 3, "extraArray should have 3 elements")
        XCTAssertEqual(extraArray[0], "first", "extraArray[0] should be 'first'")
        XCTAssertEqual(extraArray[1], "second", "extraArray[1] should be 'second'")
        XCTAssertEqual(extraArray[2], "third", "extraArray[2] should be 'third'")
        
        // Verify extra properties - Bool
        XCTAssertEqual(testModel["extraBool"] as? Bool, true, "extraBool should be present and true")
        
        // Verify extra properties - Double
        if let extraDouble = testModel["extraDouble"] as? Double
        {
            XCTAssertEqual(extraDouble, 3.14, accuracy: 0.001, "extraDouble should be present and correct")
        }
        else
        {
            XCTFail("extraDouble should be present and be a Double")
        }
        
        // Verify that all expected keys are present
        let expectedKeys: Set<String> = ["id", "name", "count", "created", "extraString", "extraInt", "extraArray", "extraBool", "extraDouble"]
        let actualKeys = Set(testModel.keys)
        
        XCTAssertTrue(expectedKeys.isSubset(of: actualKeys), "All expected keys should be present in the encoded model")
        
        try await app.asyncShutdown()
    }
    
    func testModelWithoutExtras() async throws
    {
        // Test that models without extras still work correctly
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        app.migrations.add(TestModelWithExtras.Table())
        try await app.autoMigrate()
        
        try await app.startup()
        
        // Create a simple model that doesn't override contextExtras
        final class SimpleModel: Mist.Model, Content, @unchecked Sendable
        {
            static let schema = "simple_models"
            
            @ID(key: .id) var id: UUID?
            @Field(key: "value") var value: String
            
            init() {}
            
            init(id: UUID? = nil, value: String)
            {
                self.id = id
                self.value = value
            }
        }
        
        let modelID = UUID()
        let model = SimpleModel(id: modelID, value: "simple")
        
        // Create a ModelContainer and add the model
        var container = ModelContainer()
        container.add(model, for: "simple")
        
        // Encode the container
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(container),
              let decoded = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let simpleModel = decoded["simple"] as? [String: Any]
        else
        {
            return XCTFail("Could not encode/decode simple model")
        }
        
        // Verify only base properties exist (no extras)
        XCTAssertEqual(simpleModel["value"] as? String, "simple", "Model value should match")
        XCTAssertNotNil(simpleModel["id"], "Model id should exist")
        
        // Verify that no extra properties leaked in
        XCTAssertNil(simpleModel["extraString"], "extraString should not be present")
        XCTAssertNil(simpleModel["extraInt"], "extraInt should not be present")
        XCTAssertNil(simpleModel["extraArray"], "extraArray should not be present")
        
        try await app.asyncShutdown()
    }
    
    func testComplexExtras() async throws
    {
        // Test model with complex nested extras
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        app.migrations.add(TestModelWithExtras.Table())
        try await app.autoMigrate()
        
        try await app.startup()
        
        final class ComplexExtrasModel: Mist.Model, Content, @unchecked Sendable
        {
            static let schema = "complex_extras_models"
            
            @ID(key: .id) var id: UUID?
            @Field(key: "title") var title: String
            
            init() {}
            
            init(id: UUID? = nil, title: String)
            {
                self.id = id
                self.title = title
            }
            
            func contextExtras() -> [String: any Encodable]
            {
                struct NestedData: Encodable
                {
                    let nested1: String
                    let nested2: Int
                }
                
                return [
                    "nestedObject": NestedData(nested1: "nested value", nested2: 999),
                    "arrayOfInts": [1, 2, 3, 4, 5]
                ]
            }
        }
        
        let modelID = UUID()
        let model = ComplexExtrasModel(id: modelID, title: "Complex Test")
        
        var container = ModelContainer()
        container.add(model, for: "complex")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let jsonData = try? encoder.encode(container),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else
        {
            return XCTFail("Could not encode complex model")
        }
        
        print("Complex Extras JSON:\n\(jsonString)")
        
        guard let decoded = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let complexModel = decoded["complex"] as? [String: Any]
        else
        {
            return XCTFail("Could not decode complex model")
        }
        
        // Verify base property
        XCTAssertEqual(complexModel["title"] as? String, "Complex Test", "Title should match")
        
        // Verify nested object
        guard let nestedObject = complexModel["nestedObject"] as? [String: Any] else
        {
            return XCTFail("nestedObject should be present")
        }
        XCTAssertEqual(nestedObject["nested1"] as? String, "nested value", "Nested string should match")
        XCTAssertEqual(nestedObject["nested2"] as? Int, 999, "Nested int should match")
        
        // Verify array of ints
        guard let arrayOfInts = complexModel["arrayOfInts"] as? [Int] else
        {
            return XCTFail("arrayOfInts should be present")
        }
        XCTAssertEqual(arrayOfInts, [1, 2, 3, 4, 5], "Array of ints should match")
        
        try await app.asyncShutdown()
    }
}

