import Foundation

public struct Profile: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct DomainMetric: Codable, Equatable, Identifiable, Sendable {
    public var id: String { domain }
    public let domain: String
    public let root: String?
    public let queries: Int
    public var iconDomain: String { root ?? domain }

    public init(domain: String, root: String? = nil, queries: Int) {
        self.domain = domain
        self.root = root
        self.queries = queries
    }
}

public struct LabeledMetric: Equatable, Identifiable, Sendable {
    public var id: String { label }
    public let label: String
    public let queries: Int

    public init(label: String, queries: Int) {
        self.label = label
        self.queries = queries
    }
}

public struct LogEntry: Codable, Equatable, Identifiable, Sendable {
    public struct Device: Codable, Equatable, Sendable {
        public let id: String?
        public let name: String?
        public let model: String?
    }

    public struct Reason: Codable, Equatable, Sendable {
        public let id: String
        public let name: String
    }

    public var id: String { "\(timestamp.timeIntervalSince1970)-\(domain)-\(status)" }
    public let timestamp: Date
    public let domain: String
    public let root: String?
    public let status: String
    public let protocolName: String?
    public let device: Device?
    public let reasons: [Reason]
    public var reason: String? { reasons.first?.name }
    public var iconDomain: String { root ?? domain }

    enum CodingKeys: String, CodingKey {
        case timestamp, domain, root, status, device, reasons
        case protocolName = "protocol"
    }
}

public struct LogPage: Equatable, Sendable {
    public let entries: [LogEntry]
    public let nextCursor: String?

    public init(entries: [LogEntry], nextCursor: String?) {
        self.entries = entries
        self.nextCursor = nextCursor
    }
}

public struct DashboardSnapshot: Equatable, Sendable {
    public let totalRequests: Int
    public let blockedRequests: Int
    public let allowedRequests: Int
    public let blockedDomains: [DomainMetric]
    public let protocols: [LabeledMetric]
    public let devices: [LabeledMetric]
    public let logs: [LogEntry]
    public let nextLogCursor: String?
    public let fetchedAt: Date

    public init(totalRequests: Int, blockedRequests: Int, allowedRequests: Int, blockedDomains: [DomainMetric], protocols: [LabeledMetric], devices: [LabeledMetric], logs: [LogEntry], nextLogCursor: String? = nil, fetchedAt: Date = Date()) {
        self.totalRequests = totalRequests
        self.blockedRequests = blockedRequests
        self.allowedRequests = allowedRequests
        self.blockedDomains = blockedDomains
        self.protocols = protocols
        self.devices = devices
        self.logs = logs
        self.nextLogCursor = nextLogCursor
        self.fetchedAt = fetchedAt
    }

    public func appending(logPage: LogPage) -> DashboardSnapshot {
        let existingIDs = Set(logs.map(\.id))
        let newEntries = logPage.entries.filter { !existingIDs.contains($0.id) }
        return DashboardSnapshot(
            totalRequests: totalRequests,
            blockedRequests: blockedRequests,
            allowedRequests: allowedRequests,
            blockedDomains: blockedDomains,
            protocols: protocols,
            devices: devices,
            logs: logs + newEntries,
            nextLogCursor: logPage.nextCursor,
            fetchedAt: fetchedAt
        )
    }

    public var blockRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(blockedRequests) / Double(totalRequests)
    }
}

public struct ConnectionStatus: Codable, Equatable, Sendable {
    public let status: String
    public let protocolName: String?
    public let profileID: String?

    public var isConnected: Bool { status.lowercased() == "ok" }

    enum CodingKeys: String, CodingKey {
        case status
        case protocolName = "protocol"
        case profileID = "profile"
    }

    public init(status: String, protocolName: String? = nil, profileID: String? = nil) {
        self.status = status
        self.protocolName = protocolName
        self.profileID = profileID
    }
}

public enum NextDNSClientError: LocalizedError, Equatable {
    case invalidResponse
    case server(statusCode: Int)
    case api(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: return "NextDNS returned an invalid response."
        case .server(let statusCode): return "NextDNS returned HTTP \(statusCode)."
        case .api(let detail): return detail
        }
    }
}
