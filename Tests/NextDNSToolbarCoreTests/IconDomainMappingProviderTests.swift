import XCTest
@testable import NextDNSToolbarCore

final class IconDomainMappingProviderTests: XCTestCase {
    func testRemoteMappingsBypassFreshLocalCache() async throws {
        MappingURLProtocol.handler = { request in
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-cache")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(#"{"app-measurement.com":"google.com"}"#.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MappingURLProtocol.self]
        let provider = RemoteIconMappingProvider(
            session: URLSession(configuration: configuration),
            remoteURL: URL(string: "https://example.com/mappings.json")!
        )

        let aliases = await provider.aliases()

        XCTAssertEqual(aliases["app-measurement.com"], "google.com")
    }
}

private final class MappingURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}
