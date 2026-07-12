import XCTest
@testable import NextDNSToolbarCore

final class NextDNSClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.handler = nil
    }

    func testFetchProfilesSendsAPIKeyAndDecodesProfiles() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/profiles")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "secret")
            return Self.response(for: request, json: #"{"data":[{"id":"abc123","name":"Home"},{"id":"def456","name":"Family"}]}"#)
        }

        let profiles = try await makeClient().fetchProfiles(apiKey: "secret")

        XCTAssertEqual(profiles, [
            Profile(id: "abc123", name: "Home"),
            Profile(id: "def456", name: "Family"),
        ])
    }

    func testFetchDashboardCombinesTotalsBlocksAnalyticsAndLogs() async throws {
        URLProtocolStub.handler = { request in
            let path = request.url!.path
            let query = request.url!.query ?? ""
            XCTAssertTrue(query.contains("from="))
            switch path {
            case "/profiles/abc123/analytics/status":
                return Self.response(for: request, json: #"{"data":[{"status":"default","queries":80},{"status":"blocked","queries":15},{"status":"allowed","queries":5}]}"#)
            case "/profiles/abc123/analytics/domains":
                XCTAssertTrue(query.contains("status=blocked"))
                return Self.response(for: request, json: #"{"data":[{"domain":"ads.example","queries":12},{"domain":"tracker.example","queries":3}]}"#)
            case "/profiles/abc123/analytics/protocols":
                return Self.response(for: request, json: #"{"data":[{"protocol":"DNS-over-HTTPS","queries":90},{"protocol":"UDP","queries":10}]}"#)
            case "/profiles/abc123/analytics/devices":
                return Self.response(for: request, json: #"{"data":[{"id":"mac","name":"MacBook","queries":60},{"id":"phone","name":"iPhone","queries":40}]}"#)
            case "/profiles/abc123/logs":
                XCTAssertTrue(query.contains("limit=50"))
                return Self.response(for: request, json: #"{"data":[{"timestamp":"2026-07-12T01:02:03.338Z","domain":"ads.example","status":"blocked","protocol":"DNS-over-HTTPS","device":{"id":"mac","name":"MacBook"},"reasons":[{"id":"blocklist:test","name":"Test List"}]}],"meta":{"pagination":{"cursor":"next-page"}}}"#)
            default:
                XCTFail("Unexpected path \(path)")
                return Self.response(for: request, json: #"{"data":[]}"#, status: 404)
            }
        }

        let from = Date(timeIntervalSince1970: 1_700_000_000)
        let dashboard = try await makeClient().fetchDashboard(profileID: "abc123", apiKey: "secret", from: from)

        XCTAssertEqual(dashboard.totalRequests, 100)
        XCTAssertEqual(dashboard.blockedRequests, 15)
        XCTAssertEqual(dashboard.blockedDomains.first, DomainMetric(domain: "ads.example", queries: 12))
        XCTAssertEqual(dashboard.protocols.first?.label, "DNS-over-HTTPS")
        XCTAssertEqual(dashboard.devices.first?.label, "MacBook")
        XCTAssertEqual(dashboard.logs.first?.domain, "ads.example")
        XCTAssertEqual(dashboard.logs.first?.reason, "Test List")
        XCTAssertEqual(dashboard.nextLogCursor, "next-page")
    }

    func testFetchLogsSendsCursorAndDecodesNextPage() async throws {
        URLProtocolStub.handler = { request in
            let query = request.url?.query ?? ""
            XCTAssertEqual(request.url?.path, "/profiles/abc123/logs")
            XCTAssertTrue(query.contains("cursor=current-page"))
            XCTAssertTrue(query.contains("limit=50"))
            return Self.response(for: request, json: #"{"data":[{"timestamp":"2026-07-12T01:02:03Z","domain":"github.com","status":"default","reasons":[]}],"meta":{"pagination":{"cursor":"final-page"}}}"#)
        }

        let page = try await makeClient().fetchLogs(
            profileID: "abc123",
            apiKey: "secret",
            from: Date(timeIntervalSince1970: 1_700_000_000),
            cursor: "current-page"
        )

        XCTAssertEqual(page.entries.map(\.domain), ["github.com"])
        XCTAssertEqual(page.nextCursor, "final-page")
    }

    func testConnectionStatusTreatsOkAsConnected() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.host, "test.nextdns.io")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            return Self.response(for: request, json: #"{"status":"ok","protocol":"DOH","profile":"abc123"}"#)
        }

        let status = try await makeClient().fetchConnectionStatus()

        XCTAssertTrue(status.isConnected)
        XCTAssertEqual(status.protocolName, "DOH")
        XCTAssertEqual(status.profileID, "abc123")
    }

    func testAPIErrorEnvelopeIsSurfacedEvenWith200Response() async {
        URLProtocolStub.handler = { request in
            Self.response(for: request, json: #"{"errors":[{"code":"unauthorized","detail":"Invalid API key"}]}"#)
        }

        do {
            _ = try await makeClient().fetchProfiles(apiKey: "bad")
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Invalid API key")
        }
    }

    private func makeClient() -> NextDNSClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return NextDNSClient(session: URLSession(configuration: configuration))
    }

    private static func response(for request: URLRequest, json: String, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (response, Data(json.utf8))
    }
}

private final class URLProtocolStub: URLProtocol {
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
