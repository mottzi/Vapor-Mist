import XCTest
import Vapor
import WebSocketKit
import FluentSQLiteDriver
@testable import Mist

final class ComponentDeliveryTests: XCTestCase {

    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        app.http.server.configuration.port = 0
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.views.use(.leaf)
        app.migrations.add(DummyModel1.Table())
        app.migrations.add(DummyModel2.Table())
        try await app.autoMigrate()
        
        try await app.mist.use {
            DeliveryTestRow()
        }
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
    }

    actor TestState {
        var clientID: UUID?
        var finished = false
        var error: String?

        func setClientID(_ id: UUID) { clientID = id }
        func finish() { finished = true }
        func fail(_ msg: String) { error = msg; finished = true }
    }

    private func withClientConnection(
        component: String,
        setup: @escaping @Sendable (Application, UUID) async throws -> Void,
        test: @escaping @Sendable (WebSocket, TestState) async throws -> Void
    ) async throws {
        
        let state = TestState()
        
        app.webSocket("socket") { request, ws async in
            let id = UUID()
            await state.setClientID(id)
            await request.application.mist.clients.addClient(clientID: id, socket: ws)
            await request.application.mist.clients.addSubscription(component, to: id)
        }
        
        try await app.startup()
        
        let ws: WebSocket = try await withCheckedThrowingContinuation { continuation in
            WebSocket.connect(
                host: "localhost",
                port: 8080,
                path: "/socket",
                on: app.eventLoopGroup
            ) { ws in
                continuation.resume(returning: ws)
            }.whenFailure { error in
                continuation.resume(throwing: error)
            }
        }
        
        try await test(ws, state)
        
        var clientID: UUID? = nil
        for _ in 0..<20 {
            if let captured = await state.clientID {
                clientID = captured
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        
        guard let clientID else {
            try await ws.close()
            XCTFail("Did not capture clientID in time")
            return
        }
        
        try await setup(app, clientID)
        
        let startTime = Date()
        while await !state.finished {
            if let error = await state.error {
                try await ws.close()
                XCTFail(error)
                return
            }
            if Date().timeIntervalSince(startTime) > 2.0 {
                try await ws.close()
                XCTFail("Test timed out")
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        
        try await ws.close()
    }

    func testFragmentResultRenderedSendsQueryUpdate() async throws {
        try await withClientConnection(component: "DeliveryTestRow", setup: { app, clientID in
            await app.mist.delivery.sendFragmentResult(.rendered("<div>test</div>"), for: "DeliveryTestRow", to: clientID)
        }, test: { ws, state in
            ws.onText { ws, text async in
                if text.contains("updateQueryComponent") && text.contains("DeliveryTestRow") && text.contains("<div>test</div>") {
                    await state.finish()
                } else {
                    await state.fail("Unexpected message: \\(text)")
                }
            }
        })
    }

    func testFragmentResultAbsentSendsQueryDelete() async throws {
        try await withClientConnection(component: "DeliveryTestRow", setup: { app, clientID in
            await app.mist.delivery.sendFragmentResult(.absent, for: "DeliveryTestRow", to: clientID)
        }, test: { ws, state in
            ws.onText { ws, text async in
                if text.contains("deleteQueryComponent") && text.contains("DeliveryTestRow") {
                    await state.finish()
                } else {
                    await state.fail("Unexpected message: \\(text)")
                }
            }
        })
    }

    func testFragmentResultFailedSendsNothing() async throws {
        try await withClientConnection(component: "DeliveryTestRow", setup: { app, clientID in
            await app.mist.delivery.sendFragmentResult(.failed, for: "DeliveryTestRow", to: clientID)
            // Send a follow up valid message to prove the first didn't arrive, but this did
            await app.mist.delivery.sendFragmentResult(.absent, for: "DeliveryTestRow", to: clientID)
        }, test: { ws, state in
            ws.onText { ws, text async in
                if text.contains("<div>failed</div>") || text.contains("updateQueryComponent") {
                    await state.fail("Should not have received failed update")
                } else if text.contains("deleteQueryComponent") {
                    await state.finish()
                }
            }
        })
    }

    func testDeliverInstanceMutationCreateSendsInstanceCreate() async throws {
        let modelID = UUID()
        let component = DeliveryTestRow()
        
        try await withClientConnection(component: "DeliveryTestRow", setup: { app, clientID in
            let model1 = DummyModel1(id: modelID, text: "test1")
            let model2 = DummyModel2(id: modelID, text2: "test2")
            try await model1.save(on: app.db)
            try await model2.save(on: app.db)
            
            await app.mist.delivery.deliverInstanceMutation(.create, of: component, modelID: modelID)
        }, test: { ws, state in
            ws.onText { ws, text async in
                if text.contains("createInstanceComponent") && text.contains("DeliveryTestRow") &&
                   (text.contains(modelID.uuidString.uppercased()) || text.contains(modelID.uuidString.lowercased())) {
                    await state.finish()
                } else {
                    await state.fail("Unexpected message: \\(text)")
                }
            }
        })
    }
    
    func testDeliverInstanceDeletionSendsInstanceDeleteAndClearsState() async throws {
        let modelID = UUID()
        let component = DeliveryTestRow()
        
        try await withClientConnection(component: "DeliveryTestRow", setup: { app, clientID in
            await app.mist.clients.setState(["test": .bool(true)], for: clientID, componentID: modelID.uuidString)
            let stateBefore = await app.mist.clients.getState(for: clientID, componentID: modelID.uuidString, default: [:])
            XCTAssertEqual(stateBefore["test"], .bool(true))
            
            await app.mist.delivery.deliverInstanceDeletion(of: component, modelID: modelID)
            
            let stateAfter = await app.mist.clients.getState(for: clientID, componentID: modelID.uuidString, default: [:])
            XCTAssertNil(stateAfter["test"], "State should be cleared after deletion")
        }, test: { ws, state in
            ws.onText { ws, text async in
                if text.contains("deleteInstanceComponent") && text.contains("DeliveryTestRow") &&
                   (text.contains(modelID.uuidString.uppercased()) || text.contains(modelID.uuidString.lowercased())) {
                    await state.finish()
                } else {
                    await state.fail("Unexpected message: \\(text)")
                }
            }
        })
    }

}

struct StaticTemplate: Mist.Template {
    let html: String
    func render<Context: Encodable>(context: Context, componentName: String, using app: Application) async throws -> String {
        return html
    }
}

struct DeliveryTestRow: Mist.InstanceComponent {
    let name = "DeliveryTestRow"
    let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
    let template: Mist.Template = StaticTemplate(html: "<div>test instance</div>")
}
