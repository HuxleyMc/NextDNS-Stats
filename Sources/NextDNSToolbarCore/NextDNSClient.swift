import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol NextDNSClientProtocol: Sendable {
    func fetchProfiles(apiKey: String) async throws -> [Profile]
    func fetchDashboard(profileID: String, apiKey: String, from: Date) async throws -> DashboardSnapshot
    func fetchLogs(profileID: String, apiKey: String, from: Date, cursor: String?) async throws -> LogPage
    func fetchConnectionStatus() async throws -> ConnectionStatus
}

public final class NextDNSClient: NextDNSClientProtocol, @unchecked Sendable {
    private let session: URLSession
    private let apiBaseURL: URL
    private let connectionURL: URL
    private let decoder: JSONDecoder

    public init(
        session: URLSession = .shared,
        apiBaseURL: URL = URL(string: "https://api.nextdns.io")!,
        connectionURL: URL = URL(string: "https://test.nextdns.io")!
    ) {
        self.session = session
        self.apiBaseURL = apiBaseURL
        self.connectionURL = connectionURL
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func fetchProfiles(apiKey: String) async throws -> [Profile] {
        try await get(path: "/profiles", apiKey: apiKey, query: [])
    }

    public func fetchDashboard(profileID: String, apiKey: String, from: Date) async throws -> DashboardSnapshot {
        let fromItem = URLQueryItem(name: "from", value: Self.iso8601.string(from: from))
        let escapedID = profileID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? profileID
        let prefix = "/profiles/\(escapedID)"

        async let statuses: [StatusMetric] = get(path: "\(prefix)/analytics/status", apiKey: apiKey, query: [fromItem])
        async let domains: [DomainMetric] = get(path: "\(prefix)/analytics/domains", apiKey: apiKey, query: [fromItem, URLQueryItem(name: "status", value: "blocked"), URLQueryItem(name: "limit", value: "10")])
        async let protocols: [ProtocolMetric] = get(path: "\(prefix)/analytics/protocols", apiKey: apiKey, query: [fromItem, URLQueryItem(name: "limit", value: "10")])
        async let devices: [DeviceMetric] = get(path: "\(prefix)/analytics/devices", apiKey: apiKey, query: [fromItem, URLQueryItem(name: "limit", value: "10")])
        async let logs = fetchLogs(profileID: profileID, apiKey: apiKey, from: from, cursor: nil)

        let (statusValues, domainValues, protocolValues, deviceValues, logValues) = try await (statuses, domains, protocols, devices, logs)
        return DashboardSnapshot(
            totalRequests: statusValues.reduce(0) { $0 + $1.queries },
            blockedRequests: statusValues.first(where: { $0.status == "blocked" })?.queries ?? 0,
            allowedRequests: statusValues.first(where: { $0.status == "allowed" })?.queries ?? 0,
            blockedDomains: domainValues,
            protocols: protocolValues.map { LabeledMetric(label: $0.protocolName, queries: $0.queries) },
            devices: deviceValues.map { LabeledMetric(label: $0.name ?? "Unidentified", queries: $0.queries) },
            logs: logValues.entries,
            nextLogCursor: logValues.nextCursor
        )
    }

    public func fetchLogs(profileID: String, apiKey: String, from: Date, cursor: String?) async throws -> LogPage {
        let escapedID = profileID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? profileID
        var query = [
            URLQueryItem(name: "from", value: Self.iso8601.string(from: from)),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "sort", value: "desc"),
        ]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        let envelope: APIEnvelope<[LogEntry]> = try await getEnvelope(
            path: "/profiles/\(escapedID)/logs",
            apiKey: apiKey,
            query: query
        )
        guard let entries = envelope.data else { throw NextDNSClientError.invalidResponse }
        return LogPage(entries: entries, nextCursor: envelope.meta?.pagination?.cursor)
    }

    public func fetchConnectionStatus() async throws -> ConnectionStatus {
        let (data, response) = try await session.data(from: connectionURL)
        try validate(response)
        return try decoder.decode(ConnectionStatus.self, from: data)
    }

    private func get<T: Decodable>(path: String, apiKey: String, query: [URLQueryItem]) async throws -> T {
        let envelope: APIEnvelope<T> = try await getEnvelope(path: path, apiKey: apiKey, query: query)
        guard let value = envelope.data else { throw NextDNSClientError.invalidResponse }
        return value
    }

    private func getEnvelope<T: Decodable>(path: String, apiKey: String, query: [URLQueryItem]) async throws -> APIEnvelope<T> {
        var components = URLComponents(url: apiBaseURL.appendingPathComponent(String(path.dropFirst())), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validate(response)
        let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
        if let detail = envelope.errors?.first?.detail { throw NextDNSClientError.api(detail) }
        return envelope
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw NextDNSClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw NextDNSClientError.server(statusCode: http.statusCode) }
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct APIEnvelope<Value: Decodable>: Decodable {
    let data: Value?
    let errors: [APIError]?
    let meta: APIMeta?
}

private struct APIMeta: Decodable {
    let pagination: Pagination?
}

private struct Pagination: Decodable {
    let cursor: String?
}

private struct APIError: Decodable {
    let code: String
    let detail: String
}

private struct StatusMetric: Decodable {
    let status: String
    let queries: Int
}

private struct ProtocolMetric: Decodable {
    let protocolName: String
    let queries: Int

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case queries
    }
}

private struct DeviceMetric: Decodable {
    let id: String
    let name: String?
    let queries: Int
}
