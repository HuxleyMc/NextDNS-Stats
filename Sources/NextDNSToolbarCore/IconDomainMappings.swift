import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Maps service and telemetry domains to the public brand domain whose favicon
/// should be displayed. Add new entries here as `source: brand` pairs.
public enum IconDomainMappings {
    public static let remoteURL = URL(string: "https://raw.githubusercontent.com/HuxleyMc/NextDNS-Stats/main/IconDomainMappings.json")!

    public static let fallbackAliases: [String: String] = [
        "cloudflareinsights.com": "cloudflare.com",
        "googletagmanager.com": "google.com",
        "googleapis.com": "google.com",
        "gstatic.com": "google.com",
        "appsflyersdk.com": "appsflyer.com",
        "datadoghq.com": "datadog.com",
    ]

    public static func brandDomain(for hostname: String, aliases: [String: String]) -> String? {
        aliases.keys
            .filter { hostname == $0 || hostname.hasSuffix(".\($0)") }
            .max(by: { $0.count < $1.count })
            .flatMap { aliases[$0] }
    }

    public static func validatedAliases(from data: Data) throws -> [String: String] {
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        return decoded.reduce(into: [:]) { result, item in
            guard let source = validDomain(item.key), let brand = validDomain(item.value) else { return }
            result[source] = brand
        }
    }

    private static func validDomain(_ value: String) -> String? {
        let domain = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard domain.contains("."),
              !domain.contains("/"),
              !domain.contains("://"),
              domain.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { return nil }
        return domain
    }
}

public actor RemoteIconMappingProvider {
    public static let shared = RemoteIconMappingProvider()

    private let session: URLSession
    private let remoteURL: URL
    private var cachedAliases: [String: String]?

    public init(session: URLSession = .shared, remoteURL: URL = IconDomainMappings.remoteURL) {
        self.session = session
        self.remoteURL = remoteURL
    }

    public func aliases() async -> [String: String] {
        if let cachedAliases { return cachedAliases }
        var aliases = IconDomainMappings.fallbackAliases
        do {
            var request = URLRequest(url: remoteURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.timeoutInterval = 10
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                aliases.merge(try IconDomainMappings.validatedAliases(from: data)) { _, remote in remote }
            }
        } catch {
            // Offline and malformed remote files safely fall back to bundled defaults.
        }
        cachedAliases = aliases
        return aliases
    }
}
