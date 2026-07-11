import Crypto
import Foundation
import Testing
@testable import Mist

@Suite("Mist frontend assets")
struct MistAssetTests {

    @Test("Embedded asset metadata matches its contents", arguments: MistAsset.allCases)
    func embeddedAsset(_ asset: MistAsset) throws {
        let digest = SHA256.hash(data: Data(asset.bytes))
        let hash = digest.map { String(format: "%02x", $0) }.joined()

        #expect(!asset.bytes.isEmpty)
        #expect(String(bytes: asset.bytes, encoding: .utf8) != nil)
        #expect(asset.mediaType == "text/javascript; charset=utf-8")
        #expect(asset.etag == "\"\(hash)\"")

        switch asset {
            case .mist:
                #expect(asset.filename == "mist.js")
                #expect(String(decoding: asset.bytes, as: UTF8.self).contains("class MistSocket"))
            case .morphdom:
                #expect(asset.filename == "morphdom.js")
                #expect(String(decoding: asset.bytes, as: UTF8.self).contains("window.morphdom"))
        }
    }

    @Test("Asset filenames are unique")
    func filenamesAreUnique() {
        let filenames = MistAsset.allCases.map(\.filename)
        #expect(Set(filenames).count == filenames.count)
    }

}
