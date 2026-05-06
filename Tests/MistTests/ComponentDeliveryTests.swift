import XCTest
import XCTVapor
import Vapor
import WebSocketKit
@testable import Mist

final class ComponentDeliveryTests: XCTestCase {

    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testSendFragmentResultRendered() async throws {
        let clientID = UUID()
        await app.mist.clients.addClient(clientID: clientID, socket: WebSocket.dummy)
        
        await app.mist.components.registerWOListenerForTesting(DummyRow1())
        await app.mist.clients.addSubscription("DummyRow1", to: clientID)
        
        await app.mist.delivery.sendFragmentResult(.rendered("<div>test</div>"), for: "DummyRow1", to: clientID)
        
        XCTAssertTrue(true)
    }
}
