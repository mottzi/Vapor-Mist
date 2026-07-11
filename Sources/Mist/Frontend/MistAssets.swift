import Crypto
import Foundation

/// Provides the browser runtime assets compiled into this Mist revision.
public enum MistAssets {

    public static func metadata(for asset: MistAsset) -> MistAssetMetadata {
        switch asset {
            case .mist: mist
            case .morphdom: morphdom
        }
    }

}

extension MistAssets {

    private static let mist = metadata(
        filename: "mist.js",
        bytes: PackageResources.mist_js
    )

    private static let morphdom = metadata(
        filename: "morphdom.js",
        bytes: PackageResources.morphdom_js
    )

    private static func metadata(filename: String, bytes: [UInt8]) -> MistAssetMetadata {
        let digest = SHA256.hash(data: Data(bytes))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return MistAssetMetadata(filename: filename, bytes: bytes, etag: "\"\(hash)\"")
    }

}
