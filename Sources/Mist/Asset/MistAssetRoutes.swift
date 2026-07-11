import Foundation
import Vapor

/// Convenience routing and response policies for Mist's embedded frontend assets.
public enum MistAssetRoutes {
    
    /// Registers standard GET and HEAD endpoints for all embedded Mist assets.
    public static func register(on router: RoutesBuilder, cacheControl: String = "no-cache") {
        
        for asset in MistAsset.allCases {
            let path = PathComponent(stringLiteral: asset.filename)
            
            for method in [HTTPMethod.GET, .HEAD] {
                router.on(method, path) { request in
                    Self.response(
                        for: request,
                        asset: asset,
                        cacheControl: cacheControl
                    )
                }
            }
        }
    }
    
    /// Builds a standard response for an embedded Mist asset.
    public static func response(for request: Request, asset: MistAsset, cacheControl: String = "no-cache") -> Response {
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentType, value: asset.mediaType)
        headers.replaceOrAdd(name: .cacheControl, value: cacheControl)
        headers.replaceOrAdd(name: .eTag, value: asset.etag)
        
        if matchesIfNoneMatch(request, etag: asset.etag) {
            return Response(status: .notModified, headers: headers)
        }
        
        return Response(status: .ok, headers: headers, body: Response.Body(data: Data(asset.bytes)))
    }
    
}

extension MistAssetRoutes {

    /// Returns whether the request's validators match the asset ETag.
    private static func matchesIfNoneMatch(_ request: Request, etag: String) -> Bool {
        let expected = weakETagValue(etag)

        return request.headers[.ifNoneMatch]
            .flatMap { $0.split(separator: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .contains { value in
                value == "*" || weakETagValue(value) == expected
            }
    }

    /// Removes the optional weak validator prefix from an ETag.
    private static func weakETagValue(_ value: String) -> String {
        value.hasPrefix("W/")
            ? String(value.dropFirst(2))
            : value
    }

}
