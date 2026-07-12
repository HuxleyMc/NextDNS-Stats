import XCTest
@testable import NextDNSToolbarCore

final class FaviconURLProviderTests: XCTestCase {
    func testBuildsDuckDuckGoURLForRootDomain() {
        XCTAssertEqual(
            FaviconURLProvider.url(for: "duckduckgo.com")?.absoluteString,
            "https://icons.duckduckgo.com/ip3/duckduckgo.com.ico"
        )
    }

    func testNormalizesCaseWhitespaceAndTrailingDot() {
        XCTAssertEqual(
            FaviconURLProvider.url(for: "  EXAMPLE.COM. ")?.absoluteString,
            "https://icons.duckduckgo.com/ip3/example.com.ico"
        )
    }

    func testRejectsValuesThatAreNotDomainNames() {
        XCTAssertNil(FaviconURLProvider.url(for: ""))
        XCTAssertNil(FaviconURLProvider.url(for: "https://example.com"))
        XCTAssertNil(FaviconURLProvider.url(for: "not a domain"))
    }

    func testCandidateDomainsFallBackFromHostnameToRoot() {
        XCTAssertEqual(
            FaviconURLProvider.candidateDomains(for: "collector.github.com"),
            ["collector.github.com", "github.com"]
        )
        XCTAssertEqual(
            FaviconURLProvider.candidateDomains(for: "github.com"),
            ["github.com"]
        )
    }

    func testModelsPreferRootDomainForIcons() throws {
        let metric = try JSONDecoder().decode(DomainMetric.self, from: Data(#"{"domain":"ads.example.com","root":"example.com","queries":3}"#.utf8))
        XCTAssertEqual(metric.iconDomain, "example.com")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let log = try decoder.decode(LogEntry.self, from: Data(#"{"timestamp":"2026-07-12T01:02:03Z","domain":"pixel.example.com","root":"example.com","status":"blocked","reasons":[]}"#.utf8))
        XCTAssertEqual(log.iconDomain, "example.com")
    }
}
