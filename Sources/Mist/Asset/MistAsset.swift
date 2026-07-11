import Crypto
import Foundation

/// An embedded Mist asset.
public enum MistAsset: CaseIterable, Sendable {
    
    /// The Mist client runtime script.
    case mist
    
    /// The Morphdom DOM-diffing runtime script.
    case morphdom
    
}

extension MistAsset {
    
    /// The filename by which the asset is normally served.
    public var filename: String {
        switch self {
            case .mist: "mist.js"
            case .morphdom: "morphdom.js"
        }
    }
    
    /// The media type used when serving the asset over HTTP.
    public var mediaType: String {
        switch self {
            case .mist: "text/javascript; charset=utf-8"
            case .morphdom: "text/javascript; charset=utf-8"
        }
    }
    
    /// The exact bytes embedded in this Mist revision.
    public var bytes: [UInt8] {
        switch self {
            case .mist: PackageResources.mist_js
            case .morphdom: PackageResources.morphdom_js
        }
    }
    
    /// A strong ETag derived from the exact embedded bytes.
    public var etag: String {
        switch self {
            case .mist: Self.mistETag
            case .morphdom: Self.morphdomETag
        }
    }
    
}

extension MistAsset {

    /// Cached ETag for the embedded Mist runtime script.
    private static let mistETag = makeETag(for: PackageResources.mist_js)
    
    /// Cached ETag for the embedded Morphdom runtime script.
    private static let morphdomETag = makeETag(for: PackageResources.morphdom_js)

    /// Computes a strong quoted SHA-256 ETag for asset bytes.
    private static func makeETag(for bytes: [UInt8]) -> String {
        let digest = SHA256.hash(data: Data(bytes))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return "\"\(hash)\""
    }

}
