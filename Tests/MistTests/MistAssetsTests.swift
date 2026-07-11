import Crypto
import Foundation
import Testing
@testable import Mist

@Suite("Mist frontend assets")
struct MistAssetsTests {

    @Test("Embedded asset metadata matches its contents", arguments: MistAsset.allCases)
    func embeddedAsset(_ asset: MistAsset) throws {
        let metadata = MistAssets.metadata(for: asset)
        let digest = SHA256.hash(data: Data(metadata.bytes))
        let hash = digest.map { String(format: "%02x", $0) }.joined()

        #expect(!metadata.bytes.isEmpty)
        #expect(String(bytes: metadata.bytes, encoding: .utf8) != nil)
        #expect(metadata.mediaType == "text/javascript; charset=utf-8")
        #expect(metadata.etag == "\"\(hash)\"")

        switch asset {
            case .mist:
                #expect(metadata.filename == "mist.js")
                #expect(String(decoding: metadata.bytes, as: UTF8.self).contains("class MistSocket"))
            case .morphdom:
                #expect(metadata.filename == "morphdom.js")
                #expect(String(decoding: metadata.bytes, as: UTF8.self).contains("window.morphdom"))
        }
    }

}
