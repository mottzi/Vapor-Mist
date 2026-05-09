import XCTVapor
class PortTest: XCTestCase {
    func testPort() async throws {
        let app = try await Application.make(.testing)
        app.http.server.configuration.port = 0
        try await app.startup()
        let port = app.http.server.shared.localAddress?.port
        print(port as Any)
    }
}
