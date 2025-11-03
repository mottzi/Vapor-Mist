import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import Mist

final class MistMessageTests: XCTestCase
{
    override func setUp() async throws
    {
        // reset singletons before each test
        await Mist.Clients.shared.resetForTesting()
        await Mist.Components.shared.resetForTesting()
    }
    
    // tests decoding json subscription message to Mist.Message type
    func testSubscriptionDecoding() async
    {
        let text = #"{ "subscribe": { "component": "TestComponent2" } }"#
        
        // try to decode json message to mist subscribe message
        guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
        guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
        guard case .subscribe(let component) = message else { return XCTFail("Valid but non-subscribe message") }

        XCTAssertEqual(component, "TestComponent2", "Mist message component should match JSON component string")
    }
    
    // tests encoding Mist.Message.subscribe to json
    func testSubscriptionEncoding() async
    {
        // Create a subscription message
        let subscriptionMessage = Mist.Message.subscribe(component: "TestComponent2")
        
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
    
    // tests decoding json update message to Mist.Message type
    func testUpdateDecoding() async
    {
        // Create a UUID to test with
        let testUUID = UUID()
        
        // Create JSON string for a update message
        let text =
        """
        {
            "update": {
                "component": "TestComponent",
                "id": "\(testUUID)",
                "html": "<div>Updated content</div>"
            }
        }
        """
        
        // Try to decode json message to mist update message
        guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
        guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
        
        // Verify the message is of correct type
        guard case .update(let component, /*let action,*/ let id, let html) = message else { return XCTFail("Valid but non-update message") }
        
        // Verify all fields match expected values
        XCTAssertEqual(component, "TestComponent", "Component name should match expected value")
//        XCTAssertEqual(action, "update", "Action should match expected value")
        XCTAssertEqual(id, testUUID, "UUID should match expected value")
        XCTAssertEqual(html, "<div>Updated content</div>", "HTML content should match expected value")
    }
    
    // tests encoding Mist.Message.update to json
    func testUpdateEncoding() async
    {
        // Create a UUID to test with
        let testUUID = UUID()
        
        // Create a update message
        let updateMessage = Mist.Message.update(
            component: "TestComponent",
            id: testUUID,
            html: "<div>Updated content</div>"
        )
        
        // Encode the message to JSON
        guard let jsonData = try? JSONEncoder().encode(updateMessage) else { return XCTFail("Failed to encode update message") }
        
        // Decode JSON data to a dictionary for inspection
        guard let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return XCTFail("Failed to convert json to dictionary") }
        
        // Verify JSON structure and values
        XCTAssertNotNil(dict["update"], "Should have 'update' key")
        guard let updateDict = dict["update"] as? [String: Any] else {
            return XCTFail("Update should be a dictionary")
        }
        XCTAssertEqual(updateDict["component"] as? String, "TestComponent", "Component should match")
//        XCTAssertEqual(dict["action"] as? String, "update", "Action should match")
        XCTAssertEqual(updateDict["id"] as? String, testUUID.uuidString, "UUID should match")
        XCTAssertEqual(updateDict["html"] as? String, "<div>Updated content</div>", "HTML should match")
        XCTAssertEqual(dict.count, 1, "JSON should have 1 key (the case name)")
    }
}
