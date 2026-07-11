import XCTest
import Vapor
import XCTVapor
@testable import Mist

final class MistAssetRoutesTests: XCTestCase {

    func testDefaultRoutesServeAssetsAndRespectETag() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        MistAssetRoutes.register(on: app)

        let response = try await app.sendRequest(.GET, "/mist.js")

        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(
            response.headers[.contentType].first,
            MistAsset.mist.mediaType
        )
        XCTAssertEqual(
            response.headers[.cacheControl].first,
            "no-cache"
        )
        XCTAssertEqual(
            response.headers[.eTag].first,
            MistAsset.mist.etag
        )
        XCTAssertEqual(
            response.body.readableBytes,
            MistAsset.mist.bytes.count
        )

        let headResponse = try await app.sendRequest(.HEAD, "/mist.js")
        XCTAssertEqual(headResponse.status, .ok)
        XCTAssertEqual(
            headResponse.headers[.eTag].first,
            MistAsset.mist.etag
        )

        var conditionalHeaders = HTTPHeaders()
        conditionalHeaders.replaceOrAdd(
            name: .ifNoneMatch,
            value: MistAsset.mist.etag
        )

        let conditionalResponse = try await app.sendRequest(
            .GET,
            "/mist.js",
            headers: conditionalHeaders
        )

        XCTAssertEqual(conditionalResponse.status, .notModified)
        XCTAssertEqual(conditionalResponse.body.readableBytes, 0)
    }

}
