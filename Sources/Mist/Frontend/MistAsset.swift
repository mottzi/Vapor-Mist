/// A browser runtime asset published by Mist.
public enum MistAsset: CaseIterable, Sendable {

    case mist
    case morphdom

}

/// Immutable metadata and contents for a browser runtime asset.
public struct MistAssetMetadata: Sendable {

    public let filename: String
    public let mediaType: String
    public let bytes: [UInt8]
    public let etag: String

    init(filename: String, bytes: [UInt8], etag: String) {
        self.filename = filename
        self.mediaType = "text/javascript; charset=utf-8"
        self.bytes = bytes
        self.etag = etag
    }

}
