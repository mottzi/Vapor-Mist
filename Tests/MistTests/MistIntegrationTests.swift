import XCTest
import Vapor
import Fluent
import Leaf
import FluentSQLiteDriver
@testable import Mist

final class MistIntegrationTests: XCTestCase
{
    override func setUp() async throws
    {
        // reset singleton before each test
        await Mist.Components.shared.resetForTesting()
    }
    
    // tests integrated subscription message flow: client -> server -> internal storage registry
    func testSubscriptionFlow() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // Configure Leaf as the view renderer
        app.views.use(.leaf)
        
        // register multiple components with dublicate
        await Mist.Components.shared.registerComponents([DumbComp4133()], with: app)
        
        // test this client message
        let subscriptionMessage = #"{ "subscribe": { "component": "DumbComp4133" } }"#
        
        // set up websocket on server
        app.webSocket("socket")
        { request, ws async in
            
            let app = request.application
            
            // create client
            let clientID = UUID()
            
            // use API to add client to internal storage
            await app.mist.clients.addClient(id: clientID, socket: ws)
            
            // get internal storage
            let clients = await app.mist.clients.clients
            
            // test internal storage after adding client
            XCTAssertEqual(clients.count, 1, "Only one client should exist")
            XCTAssertEqual(clients[0].id, clientID, "Client ID should match")
            XCTAssertEqual(clients[0].subscriptions.count, 0, "Client should not have subscriptions")
            
            ws.onText()
            { ws, text async in
                print("*** server receiving message: \(text)")
                
                // make sure sent client message and received server message match
                XCTAssertEqual(text, subscriptionMessage, "Sent and received message should match")
                
                // try to decode json message to typed mist message
                guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
                guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
                
                switch message
                {
                    // ensure correct decoding
                    case .subscribe(let component): do
                    {
                        // test correct decoding of component name
                        XCTAssertEqual(component, "DumbComp4133", "Mist message component should match JSON component string")
                        
                        // use API to add client sent component name to client's subscription set
                        let added = await app.mist.clients.addSubscription(component, to: clientID)
                        XCTAssertEqual(added, true, "Component not found (or client)")

                        // get internal storage
                        let clients = await app.mist.clients.clients
                        
                        // test internal storage after adding subscription
                        XCTAssertEqual(clients.count, 1, "Only one client should exist")
                        XCTAssertEqual(clients[0].subscriptions.count, 1, "Client should have exactly one subscription")
                        XCTAssert(clients[0].subscriptions.contains("DumbComp4133"), "Client should be subscribed to component")
                    }
                        
                    // ensure correct decoding
                    default: return XCTFail("Valid but non-subscribe message")
                }
            }
        }
        
        // start server (will block indefinitly and cause timeout, that's fine atm)
        try await app.startup()
        
        // client connects to server socket
        try await WebSocket.connect(to: "ws://localhost:8080/socket")
        { ws in
            Task
            {
                print("*** client sending subscription message: \(subscriptionMessage)")
                
                // send component subscription message to client -> server
                ws.send(subscriptionMessage)
            }
        }
        
        try await app.asyncShutdown()
    }
    
    // tests integrated subscription message flow: client -> server -> internal storage registry
    // tests integrated update message flow: server -> client
    func testUpdateFlow() async throws
    {
        // test timeout duration
        let testTimeout: TimeInterval = 2.0
        
        // set up application and database
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // Configure Leaf as the view renderer
        app.views.use(.leaf)
        
        // add migrations
        app.migrations.add(DummyModel1.Table(), DummyModel2.Table())
        try await app.autoMigrate()
        
        // configure mist with our test component
        await Mist.Components.shared.registerComponents([TestComponent()], with: app)
        
        // subscription message
        let subscriptionMessage = #"{ "subscribe": { "component": "TestComponent" } }"#
        
        // create component models
        let modelID = UUID()
        
        let model1 = DummyModel1(id: modelID, text: "Initial text")
        let model2 = DummyModel2(id: modelID, text2: "Initial text 2")
        
        let model1UpdatedText = "Component Model Updated!"
        
        // actor to safely track test state across async boundaries
        actor TestState
        {
            var success = false
            var error: String?
            
            func pass() { success = true }
            func fail(_ message: String) { error = message }
        }
        
        let test = TestState()
        
        // set up WebSocket server
        app.webSocket("socket")
        { request, ws async in
            
            let app = request.application
            
            // add client to registry
            let clientID = UUID()
            await app.mist.clients.addClient(id: clientID, socket: ws)
            
            // handle client messages
            ws.onText()
            { ws, text async in
                print("*** Server receiving: \(text)")
                
                // decode subscription message
                guard let data = text.data(using: .utf8),
                      let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else
                {
                    return await test.fail("Failed to decode client message")
                }
                
                guard case .subscribe(let component) = message else { return await test.fail("Unsupported message type") }
    
                // add subscription
                let added = await app.mist.clients.addSubscription(component, to: clientID)
                guard added else { return await test.fail("Failed to add subscription") }
                
                // create and update models to trigger listener
                print("*** Server creating and updating models...")
                
                do
                {
                    // save component models to database
                    try await model1.save(on: request.db)
                    try await model2.save(on: request.db)
                    
                    // update component model to trigger component update
                    model1.text = model1UpdatedText
                    try await model1.save(on: request.db)
                }
                catch
                {
                    await test.fail("Failed to save models: \(error)")
                }
                
            }
        }
        
        // Start the server
        try await app.startup()
        
        // Connect client to server
        try await WebSocket.connect(host: "localhost", port: 8080, path: "/socket", on: app.eventLoopGroup)
        { ws async in
            // Send subscription message when connected
            print("*** Client sending: \(subscriptionMessage)")
            do { try await ws.send(subscriptionMessage) } catch { return await test.fail("Failed to send subscription message") }
            
            // Handle incoming messages from server
            ws.onText
            { ws, text async in
                print("*** Client received server message...")
                
                // decode to Mist.Message
                guard let data = text.data(using: .utf8) else { return await test.fail("Error decoding") }
                guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return await test.fail("Error decoding") }
  
                // verify update message
                guard case .update(let component, /*_,*/ let id, let html) = message else { return await test.fail("Wrong Mist.Message received") }
                guard component == "TestComponent" else { return await test.fail("Wrong Component received") }
                guard id == modelID else { return await test.fail("Wrong model ID received") }
                
                print("*** Client received HTML:\n\(html)")

                guard html ==
                """
                <div mist-component="TestComponent" mist-id="\(modelID.uuidString)">
                    <span>\(modelID.uuidString)</span>
                    <span>\(model1UpdatedText)</span>
                    <span>Initial text 2</span>
                </div>
                """ else { return await test.fail("Not expected updated HTML") }
        
                // test finished
                await test.pass()
            }
        }
        
        // Wait with timeout for the update message
        let startTime = Date()
        
        while await !test.success
        {
            // Check for any error state
            if let error = await test.error
            {
                XCTFail("Test failed with error: \(error)")
                break
            }
            
            // Check for timeout
            if Date().timeIntervalSince(startTime) > testTimeout
            {
                XCTFail("Test timed out after \(testTimeout) seconds waiting for component update")
                break
            }
            
            // Small sleep to prevent tight polling
            try await Task.sleep(for: .milliseconds(100))
        }
        
        // Final check if update was received
        let testPassed = await test.success
        XCTAssertTrue(testPassed, "Client did not receive the expected update")
        
        // Clean up
        try await app.asyncShutdown()
    }
}
    
struct DumbComp4133: Mist.Component
{
    let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
}

struct TestComponent: MistTests.TestableComponent
{
    
    let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
    
    func templateStringLiteral(id: UUID) -> String
    {
        """
        <div mist-component="TestComponent" mist-id="\(id)">
            <span>#(component.dummymodel1.id)</span>
            <span>#(component.dummymodel1.text)</span>
            <span>#(component.dummymodel2.text2)</span>
        </div>
        """
    }
    
}

