import XCTest
import Vapor
import FluentSQLiteDriver
@testable import WebSocketKit
@testable import Mist

final class MistClientsTests: XCTestCase
{
    override func setUp() async throws
    {
        // reset singletons before each test
        await Mist.Clients.shared.resetForTesting()
        await Mist.Components.shared.resetForTesting()
    }
    
    // tests correct adding of new client
    func testAddClient() async
    {
        // add new test client
        let clientID = await addTestClient()
        
        // load internal storage
        let clients = await Mist.Clients.shared.getClients()
        
        // test internal storage after adding client
        XCTAssertEqual(clients.count, 1, "Only one client should exist")
        XCTAssertEqual(clients[0].id, clientID, "Client ID should match")
        XCTAssertEqual(clients[0].subscriptions.count, 0, "Client should not have subscriptions")
    }
    
    // tests correct removal of client
    func testRemoveClient() async
    {
        // add test client
        let clientID = await addTestClient()
        
        // remove test client
        await Mist.Clients.shared.removeClient(id: clientID)
        
        // load internal storage
        let clients = await Mist.Clients.shared.getClients()
        
        // test internal storage
        XCTAssertEqual(clients.count, 0, "No clients should exist")
    }
    
    // tests correct component subscribtion of clients
    func testAddSubscription() async
    {
        // create test client
        let clientID0 = await addTestClient()
        let clientID1 = await addTestClient()
        let clientID2 = await addTestClient()
        
        // use testing API to register component
        await Mist.Components.shared.registerWOListenerForTesting(DummyRow1())
        await Mist.Components.shared.registerWOListenerForTesting(DummyRow2())
        
        // use API to add component name to client's subscription set
        var inserted: Bool
        
        // valid
        inserted = await Mist.Clients.shared.addSubscription("DummyRow1", to: clientID0)
        XCTAssertEqual(inserted, true)
        
        // valid
        inserted = await Mist.Clients.shared.addSubscription("DummyRow1", to: clientID1)
        XCTAssertEqual(inserted, true)
        
        // valid
        inserted = await Mist.Clients.shared.addSubscription("DummyRow2", to: clientID1)
        XCTAssertEqual(inserted, true)
        
        // invalid (already subscribed)
        inserted = await Mist.Clients.shared.addSubscription("DummyRow2", to: clientID1)
        XCTAssertEqual(inserted, false)

        // invalid (no such component)
        inserted = await Mist.Clients.shared.addSubscription("DummyRow3", to: clientID2)
        XCTAssertEqual(inserted, false)
        
        // invalid (no such client)
        inserted = await Mist.Clients.shared.addSubscription("DummyRow3", to: UUID())
        XCTAssertEqual(inserted, false)

        // load internal storage
        let clients = await Mist.Clients.shared.getClients()
        
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
    func testGetSubscribers() async
    {
        let clientID0 = await addTestClient()
        let clientID1 = await addTestClient()
        let clientID2 = await addTestClient()

        // use testing API to register components
        await Mist.Components.shared.registerWOListenerForTesting(DummyRow1())
        await Mist.Components.shared.registerWOListenerForTesting(DummyRow2())
    
        await Mist.Clients.shared.addSubscription("DummyRow1", to: clientID0)
        
        await Mist.Clients.shared.addSubscription("DummyRow1", to: clientID1)
        await Mist.Clients.shared.addSubscription("DummyRow2", to: clientID1)
        await Mist.Clients.shared.addSubscription("DummyRow2", to: clientID1)
        
        await Mist.Clients.shared.addSubscription("DummyRow3", to: clientID2)
        await Mist.Clients.shared.addSubscription("DummyRow3", to: UUID())
        
        let subscribers1 = await Mist.Clients.shared.getSubscribers(of: "DummyRow1").map { $0.id }
        XCTAssertEqual(subscribers1, [clientID0, clientID1])
        
        let subscribers2 = await Mist.Clients.shared.getSubscribers(of: "DummyRow2").map { $0.id }
        XCTAssertEqual(subscribers2, [clientID1])
        
        let subscribers3 = await Mist.Clients.shared.getSubscribers(of: "DummyRow3").map { $0.id }
        XCTAssertEqual(subscribers3, [])
    }
    
    // tests that reverse index is correctly maintained during subscription operations
    func testComponentToClientsReverseIndex() async
    {
        // setup
        let clientID0 = await addTestClient()
        let clientID1 = await addTestClient()
        let clientID2 = await addTestClient()
        
        await Mist.Components.shared.registerWOListenerForTesting(DummyRow1())
        await Mist.Components.shared.registerWOListenerForTesting(DummyRow2())
        
        // add subscriptions
        await Mist.Clients.shared.addSubscription("DummyRow1", to: clientID0)
        await Mist.Clients.shared.addSubscription("DummyRow1", to: clientID1)
        await Mist.Clients.shared.addSubscription("DummyRow2", to: clientID1)
        await Mist.Clients.shared.addSubscription("DummyRow2", to: clientID2)
        
        // test reverse index lookup
        let subscribers1 = await Mist.Clients.shared.getSubscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers1.count, 2, "DummyRow1 should have 2 subscribers")
        XCTAssertTrue(subscribers1.contains(where: { $0.id == clientID0 }))
        XCTAssertTrue(subscribers1.contains(where: { $0.id == clientID1 }))
        
        let subscribers2 = await Mist.Clients.shared.getSubscribers(of: "DummyRow2")
        XCTAssertEqual(subscribers2.count, 2, "DummyRow2 should have 2 subscribers")
        XCTAssertTrue(subscribers2.contains(where: { $0.id == clientID1 }))
        XCTAssertTrue(subscribers2.contains(where: { $0.id == clientID2 }))
        
        // test non-existent component
        let subscribers3 = await Mist.Clients.shared.getSubscribers(of: "NonExistent")
        XCTAssertEqual(subscribers3.count, 0, "Non-existent component should have no subscribers")
    }
    
    // tests that reverse index is cleaned up when clients disconnect
    func testReverseIndexCleanupOnRemove() async
    {
        // setup
        let clientID0 = await addTestClient()
        let clientID1 = await addTestClient()
        
        await Mist.Components.shared.registerWOListenerForTesting(DummyRow1())
        await Mist.Components.shared.registerWOListenerForTesting(DummyRow2())
        
        // both clients subscribe to both components
        await Mist.Clients.shared.addSubscription("DummyRow1", to: clientID0)
        await Mist.Clients.shared.addSubscription("DummyRow2", to: clientID0)
        await Mist.Clients.shared.addSubscription("DummyRow1", to: clientID1)
        await Mist.Clients.shared.addSubscription("DummyRow2", to: clientID1)
        
        // verify initial state
        var subscribers1 = await Mist.Clients.shared.getSubscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers1.count, 2)
        
        var subscribers2 = await Mist.Clients.shared.getSubscribers(of: "DummyRow2")
        XCTAssertEqual(subscribers2.count, 2)
        
        // remove first client
        await Mist.Clients.shared.removeClient(id: clientID0)
        
        // verify reverse index was updated
        subscribers1 = await Mist.Clients.shared.getSubscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers1.count, 1, "DummyRow1 should have 1 subscriber after removal")
        XCTAssertEqual(subscribers1[0].id, clientID1)
        
        subscribers2 = await Mist.Clients.shared.getSubscribers(of: "DummyRow2")
        XCTAssertEqual(subscribers2.count, 1, "DummyRow2 should have 1 subscriber after removal")
        XCTAssertEqual(subscribers2[0].id, clientID1)
        
        // remove second client
        await Mist.Clients.shared.removeClient(id: clientID1)
        
        // verify reverse index is empty (no memory leaks)
        subscribers1 = await Mist.Clients.shared.getSubscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers1.count, 0, "DummyRow1 should have no subscribers")
        
        subscribers2 = await Mist.Clients.shared.getSubscribers(of: "DummyRow2")
        XCTAssertEqual(subscribers2.count, 0, "DummyRow2 should have no subscribers")
        
        // verify internal state is clean (no memory leaks)
        let reverseIndexIsEmpty = await Mist.Clients.shared.getReverseIndexForTesting().isEmpty
        XCTAssertTrue(reverseIndexIsEmpty, "Reverse index should be completely empty after all clients removed")
    }
    
    // tests that component key is removed from reverse index when last subscriber is removed
    func testLastSubscriberRemoval() async
    {
        let clientID = await addTestClient()
        
        await Mist.Components.shared.registerWOListenerForTesting(DummyRow1())
        
        // subscribe single client
        await Mist.Clients.shared.addSubscription("DummyRow1", to: clientID)
        
        // verify subscription exists
        var subscribers = await Mist.Clients.shared.getSubscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers.count, 1)
        
        // verify component key exists in reverse index
        var reverseIndex = await Mist.Clients.shared.getReverseIndexForTesting()
        XCTAssertTrue(reverseIndex.keys.contains("DummyRow1"), "Component should exist in reverse index")
        
        // remove the only subscriber
        await Mist.Clients.shared.removeClient(id: clientID)
        
        // verify subscriber list is empty
        subscribers = await Mist.Clients.shared.getSubscribers(of: "DummyRow1")
        XCTAssertEqual(subscribers.count, 0)
        
        // verify component key is removed from reverse index (no memory leak)
        reverseIndex = await Mist.Clients.shared.getReverseIndexForTesting()
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
    private func addTestClient() async -> UUID
    {
        // create test client
        let clientID = UUID()
        
        // use API to add test client to internal storage
        await Mist.Clients.shared.addClient(id: clientID, socket: WebSocket.dummy)
        
        return clientID
    }
}
