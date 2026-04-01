import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import Mist

final class MistMessageTests: XCTestCase
{    
    // tests decoding json subscription message to MistMessage type
    func testSubscriptionDecoding() async
    {
        let text = #"{ "subscribe": { "component": "TestComponent2" } }"#
        
        // try to decode json message to mist subscribe message
        guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
        guard let message = try? JSONDecoder().decode(MistMessage.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
        guard case .subscribe(let component) = message else { return XCTFail("Valid but non-subscribe message") }

        XCTAssertEqual(component, "TestComponent2", "Mist message component should match JSON component string")
    }
    
    // tests encoding MistMessage.subscribe to json
    func testSubscriptionEncoding() async
    {
        // Create a subscription message
        let subscriptionMessage = MistMessage.subscribe(component: "TestComponent2")
        
        // Encode the message to JSON
        guard let jsonData = try? JSONEncoder().encode(subscriptionMessage) else { return XCTFail("Failed to encode subscription message") }
        
        // Decode JSON data to a dictionary for inspection
        guard let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return XCTFail("Failed to convert json to dictionary") }
        
        // Verify JSON structure and values
        XCTAssertNotNil(dict["subscribe"], "Should have 'subscribe' key")
        guard let subscribeDict = dict["subscribe"] as? [String: Any] else { return XCTFail("Subscribe should be a dictionary") }
        XCTAssertEqual(subscribeDict["component"] as? String, "TestComponent2", "Component should match")
        XCTAssertEqual(dict.count, 1, "JSON should only have 1 key (the case name)")
    }
    
    // tests decoding json instanceUpdate message to MistMessage type
    func testInstanceUpdateDecoding() async
    {
        // Create a UUID to test with
        let testUUID = UUID()
        
        // Create JSON string for an instance update message
        let text =
        """
        {
            "updateInstanceComponent": {
                "component": "TestComponent",
                "modelID": "\(testUUID)",
                "html": "<div>Updated content</div>"
            }
        }
        """
        
        // Try to decode json message to mist instance update message
        guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
        guard let message = try? JSONDecoder().decode(MistMessage.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
        
        // Verify the message is of correct type
        guard case .updateInstanceComponent(let component, let modelID, let html) = message else { return XCTFail("Valid but non-updateInstanceComponent message") }
        
        // Verify all fields match expected values
        XCTAssertEqual(component, "TestComponent", "Component name should match expected value")
        XCTAssertEqual(modelID, testUUID, "UUID should match expected value")
        XCTAssertEqual(html, "<div>Updated content</div>", "HTML content should match expected value")
    }
    
    // tests encoding MistMessage.instanceUpdate to json
    func testInstanceUpdateEncoding() async
    {
        // Create a UUID to test with
        let testUUID = UUID()
        
        // Create an instance update message
        let updateMessage = MistMessage.updateInstanceComponent(
            component: "TestComponent",
            modelID: testUUID,
            html: "<div>Updated content</div>"
        )
        
        // Encode the message to JSON
        guard let jsonData = try? JSONEncoder().encode(updateMessage) else { return XCTFail("Failed to encode instance update message") }
        
        // Decode JSON data to a dictionary for inspection
        guard let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return XCTFail("Failed to convert json to dictionary") }
        
        // Verify JSON structure and values
        XCTAssertNotNil(dict["updateInstanceComponent"], "Should have 'updateInstanceComponent' key")
        guard let updateDict = dict["updateInstanceComponent"] as? [String: Any] else {
            return XCTFail("updateInstanceComponent should be a dictionary")
        }
        XCTAssertEqual(updateDict["component"] as? String, "TestComponent", "Component should match")
        XCTAssertEqual(updateDict["modelID"] as? String, testUUID.uuidString, "UUID should match")
        XCTAssertEqual(updateDict["html"] as? String, "<div>Updated content</div>", "HTML should match")
        XCTAssertEqual(dict.count, 1, "JSON should have 1 key (the case name)")
    }
    
    // tests decoding json queryUpdate message to MistMessage type
    func testQueryUpdateDecoding() async
    {
        // Create JSON string for a query update message (no ID)
        let text =
        """
        {
            "updateQueryComponent": {
                "component": "TestQueryComponent",
                "html": "<div>Query result content</div>"
            }
        }
        """
        
        // Try to decode json message to mist query update message
        guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
        guard let message = try? JSONDecoder().decode(MistMessage.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
        
        // Verify the message is of correct type
        guard case .updateQueryComponent(let component, let html) = message else { return XCTFail("Valid but non-updateQueryComponent message") }
        
        // Verify all fields match expected values
        XCTAssertEqual(component, "TestQueryComponent", "Component name should match expected value")
        XCTAssertEqual(html, "<div>Query result content</div>", "HTML content should match expected value")
    }
    
    // tests encoding MistMessage.queryUpdate to json
    func testQueryUpdateEncoding() async
    {
        // Create a query update message
        let updateMessage = MistMessage.updateQueryComponent(
            component: "TestQueryComponent",
            html: "<div>Query result content</div>"
        )
        
        // Encode the message to JSON
        guard let jsonData = try? JSONEncoder().encode(updateMessage) else { return XCTFail("Failed to encode query update message") }
        
        // Decode JSON data to a dictionary for inspection
        guard let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return XCTFail("Failed to convert json to dictionary") }
        
        // Verify JSON structure and values
        XCTAssertNotNil(dict["updateQueryComponent"], "Should have 'updateQueryComponent' key")
        guard let updateDict = dict["updateQueryComponent"] as? [String: Any] else {
            return XCTFail("updateQueryComponent should be a dictionary")
        }
        XCTAssertEqual(updateDict["component"] as? String, "TestQueryComponent", "Component should match")
        XCTAssertEqual(updateDict["html"] as? String, "<div>Query result content</div>", "HTML should match")
        XCTAssertEqual(dict.count, 1, "JSON should have 1 key (the case name)")
    }
}
