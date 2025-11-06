import XCTest
import Vapor
import FluentSQLiteDriver
@testable import WebSocketKit
@testable import Mist

final class MistClientsTests: XCTestCase
{    
    // tests correct adding of new client
    func testAddClient() async throws
    {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        
        // add new test client
        let clientID = await addTestClient(app: app)
        
        // load internal storage
        let clients = await app.mist.clients.clients
        
        // test internal storage after adding client
        XCTAssertEqual(clients.count, 1, "Only one client should exist")
        XCTAssertEqual(clients[0].id, clientID, "Client ID should match")
        XCTAssertEqual(clients[0].subscriptions.count, 0, "Client should not have subscriptions")
    }
    
    // tests correct removal of client
    func testRemoveClient() async throws
    {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        
        // add test client
        let clientID = await addTestClient(app: app)
        
        // remove test client
        await app.mist.clients.removeClient(id: clientID)
        
        // load internal storage
        let clients = await app.mist.clients.clients
        
        // test internal storage
        XCTAssertEqual(clients.count, 0, "No clients should exist")
    }
    
    // tests correct component subscribtion of clients
    func testAddSubscription() async throws
    {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        
        // create test client
        let clientID0 = await addTestClient(app: app)
        let clientID1 = await addTestClient(app: app)
        let clientID2 = await addTestClient(app: app)
        
        // use testing API to register component
        await app.mist.components.registerWOListenerForTesting(DummyRow1())
        await app.mist.components.registerWOListenerForTesting(DummyRow2())
        
        // use API to add component name to client's subscription set
        var inserted: Bool
        
        // valid
        inserted = await app.mist.clients.addSubscription("DummyRow1", to: clientID0)
        XCTAssertEqual(inserted, true)
        
        // valid
        inserted = await app.mist.clients.addSubscription("DummyRow1", to: clientID1)
        XCTAssertEqual(inserted, true)
        
        // valid
        inserted = await app.mist.clients.addSubscription("DummyRow2", to: clientID1)
        XCTAssertEqual(inserted, true)
        
        // invalid (already subscribed)
        inserted = await app.mist.clients.addSubscription("DummyRow2", to: clientID1)
        XCTAssertEqual(inserted, false)

        // invalid (no such component)
        inserted = await app.mist.clients.addSubscription("DummyRow3", to: clientID2)
        XCTAssertEqual(inserted, false)
        
        // invalid (no such client)
        inserted = await app.mist.clients.addSubscription("DummyRow3", to: UUID())
        XCTAssertEqual(inserted, false)

        // load internal storage
        let clients = await app.mist.clients.clients
        
        // test internal storage after adding subscriptions to clients
        XCTAssertEqual(clients.count, 3, "Only 4 clients should exist")
        
        XCTAssertEqual(clients[0].subscriptions.count, 1)
        XCTAssert(clients[0].subscriptions.contains("DummyRow1"))
        
        XCTAssertEqual(clients[1].subscriptions.count, 2)
        XCTAssert(clients[1].subscriptions.contains("DummyRow1"))
        XCTAssert(clients[1].subscriptions.contains("DummyRow2"))
        
        XCTAssertEqual(clients[2].subscriptions.count, 0)
    }
    
    // tests correct lookup of component subscribed clients
    func testGetSubscribers() async throws
    {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        
        let clientID0 = await addTestClient(app: app)
        let clientID1 = await addTestClient(app: app)
        let clientID2 = await addTestClient(app: app)

        // use testing API to register components
        await app.mist.components.registerWOListenerForTesting(DummyRow1())
        await app.mist.components.registerWOListenerForTesting(DummyRow2())
    
        await app.mist.clients.addSubscription("DummyRow1", to: clientID0)
        
        await app.mist.clients.addSubscription("DummyRow1", to: clientID1)
        await app.mist.clients.addSubscription("DummyRow2", to: clientID1)
        await app.mist.clients.addSubscription("DummyRow2", to: clientID1)
        
        await app.mist.clients.addSubscription("DummyRow3", to: clientID2)
        await app.mist.clients.addSubscription("DummyRow3", to: UUID())
        
        let subscribers1 = await app.mist.clients.subscribers(of: "DummyRow1").map { $0.id }
        XCTAssertEqual(subscribers1, [clientID0, clientID1])
        
        let subscribers2 = await app.mist.clients.subscribers(of: "DummyRow2").map { $0.id }
        XCTAssertEqual(subscribers2, [clientID1])
        
        let subscribers3 = await app.mist.clients.subscribers(of: "DummyRow3").map { $0.id }
        XCTAssertEqual(subscribers3, [])
    }
    
    // tests that reverse index is correctly maintained during subscription operations
    func testComponentToClientsReverseIndex() async throws
    {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        
        // setup
        let clientID0 = await addTestClient(app: app)
        let clientID1 = await addTestClient(app: app)
        let clientID2 = await addTestClient(app: app)
        
        await app.mist.components.registerWOListenerForTesting(DummyRow1())
        await app.mist.components.registerWOListenerForTesting(DummyRow2())
        
        // add subscriptions
        await app.mist.clients.addSubscription("DummyRow1", to: clientID0)
        await app.mist.clients.addSubscription("DummyRow1", to: clientID1)
        await app.mist.clients.addSubscription("DummyRow2", to: clientID1)
        await app.mist.clients.addSubscription("DummyRow2", to: clientID2)
        
        // test reverse index lookup
        let subscribers1 = await app.mist.clients.subscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers1.count, 2, "DummyRow1 should have 2 subscribers")
        XCTAssertTrue(subscribers1.contains(where: { $0.id == clientID0 }))
        XCTAssertTrue(subscribers1.contains(where: { $0.id == clientID1 }))
        
        let subscribers2 = await app.mist.clients.subscribers(of: "DummyRow2")
        XCTAssertEqual(subscribers2.count, 2, "DummyRow2 should have 2 subscribers")
        XCTAssertTrue(subscribers2.contains(where: { $0.id == clientID1 }))
        XCTAssertTrue(subscribers2.contains(where: { $0.id == clientID2 }))
        
        // test non-existent component
        let subscribers3 = await app.mist.clients.subscribers(of: "NonExistent")
        XCTAssertEqual(subscribers3.count, 0, "Non-existent component should have no subscribers")
    }
    
    // tests that reverse index is cleaned up when clients disconnect
    func testReverseIndexCleanupOnRemove() async throws
    {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        
        // setup
        let clientID0 = await addTestClient(app: app)
        let clientID1 = await addTestClient(app: app)
        
        await app.mist.components.registerWOListenerForTesting(DummyRow1())
        await app.mist.components.registerWOListenerForTesting(DummyRow2())
        
        // both clients subscribe to both components
        await app.mist.clients.addSubscription("DummyRow1", to: clientID0)
        await app.mist.clients.addSubscription("DummyRow2", to: clientID0)
        await app.mist.clients.addSubscription("DummyRow1", to: clientID1)
        await app.mist.clients.addSubscription("DummyRow2", to: clientID1)
        
        // verify initial state
        var subscribers1 = await app.mist.clients.subscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers1.count, 2)
        
        var subscribers2 = await app.mist.clients.subscribers(of: "DummyRow2")
        XCTAssertEqual(subscribers2.count, 2)
        
        // remove first client
        await app.mist.clients.removeClient(id: clientID0)
        
        // verify reverse index was updated
        subscribers1 = await app.mist.clients.subscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers1.count, 1, "DummyRow1 should have 1 subscriber after removal")
        XCTAssertEqual(subscribers1[0].id, clientID1)
        
        subscribers2 = await app.mist.clients.subscribers(of: "DummyRow2")
        XCTAssertEqual(subscribers2.count, 1, "DummyRow2 should have 1 subscriber after removal")
        XCTAssertEqual(subscribers2[0].id, clientID1)
        
        // remove second client
        await app.mist.clients.removeClient(id: clientID1)
        
        // verify reverse index is empty (no memory leaks)
        subscribers1 = await app.mist.clients.subscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers1.count, 0, "DummyRow1 should have no subscribers")
        
        subscribers2 = await app.mist.clients.subscribers(of: "DummyRow2")
        XCTAssertEqual(subscribers2.count, 0, "DummyRow2 should have no subscribers")
        
        // verify internal state is clean (no memory leaks)
        let reverseIndexIsEmpty = await app.mist.clients.componentToClients.isEmpty
        XCTAssertTrue(reverseIndexIsEmpty, "Reverse index should be completely empty after all clients removed")
    }
    
    // tests that component key is removed from reverse index when last subscriber is removed
    func testLastSubscriberRemoval() async throws
    {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        
        let clientID = await addTestClient(app: app)
        
        await app.mist.components.registerWOListenerForTesting(DummyRow1())
        
        // subscribe single client
        await app.mist.clients.addSubscription("DummyRow1", to: clientID)
        
        // verify subscription exists
        var subscribers = await app.mist.clients.subscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers.count, 1)
        
        // verify component key exists in reverse index
        var reverseIndex = await app.mist.clients.componentToClients
        XCTAssertTrue(reverseIndex.keys.contains("DummyRow1"), "Component should exist in reverse index")
        
        // remove the only subscriber
        await app.mist.clients.removeClient(id: clientID)
        
        // verify subscriber list is empty
        subscribers = await app.mist.clients.subscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers.count, 0)
        
        // verify component key is removed from reverse index (no memory leak)
        reverseIndex = await app.mist.clients.componentToClients
        XCTAssertFalse(reverseIndex.keys.contains("DummyRow1"), "Component key should be removed when last subscriber is removed")
    }
}

extension WebSocket
{
    static var dummy: WebSocket
    {
        WebSocket(channel: EmbeddedChannel(loop: EmbeddedEventLoop()), type: PeerType.server)
    }
}

extension MistClientsTests
{
    private func addTestClient(app: Application) async -> UUID
    {
        // create test client
        let clientID = UUID()
        
        // use API to add test client to internal storage
        await app.mist.clients.addClient(id: clientID, socket: WebSocket.dummy)
        
        return clientID
    }
}
