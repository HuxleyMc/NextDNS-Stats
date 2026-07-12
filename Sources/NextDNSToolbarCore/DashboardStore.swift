import Combine
import Foundation

@MainActor
public final class DashboardStore: ObservableObject {
    @Published public private(set) var profiles: [Profile] = []
    @Published public private(set) var selectedProfileID: String?
    @Published public private(set) var snapshot: DashboardSnapshot?
    @Published public private(set) var connection = ConnectionStatus(status: "unknown")
    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let client: any NextDNSClientProtocol
    private let credentials: any CredentialStoring
    private let refreshInterval: Duration
    private let refreshClock = ContinuousClock()
    private var apiKey: String?
    private var refreshTask: Task<Void, Never>?
    private var lastRefreshAttempt: ContinuousClock.Instant?

    public init(
        client: any NextDNSClientProtocol = NextDNSClient(),
        credentials: any CredentialStoring = KeychainCredentialStore(),
        refreshInterval: Duration = .seconds(30)
    ) {
        self.client = client
        self.credentials = credentials
        self.refreshInterval = refreshInterval
        do {
            self.apiKey = try credentials.loadAPIKey()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func startRefreshing() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshIfStale()
                do {
                    try await Task.sleep(for: self.refreshInterval)
                } catch {
                    return
                }
            }
        }
    }

    public func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func refreshIfStale() async {
        if let lastRefreshAttempt,
           lastRefreshAttempt.duration(to: refreshClock.now) < refreshInterval {
            return
        }
        await refresh()
    }

    public func refresh() async {
        lastRefreshAttempt = refreshClock.now
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            connection = try await client.fetchConnectionStatus()
        } catch {
            connection = ConnectionStatus(status: "unavailable")
        }

        guard let apiKey, !apiKey.isEmpty else {
            isAuthenticated = false
            return
        }

        do {
            if profiles.isEmpty {
                profiles = try await client.fetchProfiles(apiKey: apiKey)
                if selectedProfileID == nil || !profiles.contains(where: { $0.id == selectedProfileID }) {
                    selectedProfileID = profiles.first?.id
                }
            }
            guard let selectedProfileID else {
                isAuthenticated = true
                return
            }
            let from = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date().addingTimeInterval(-86_400)
            snapshot = try await client.fetchDashboard(profileID: selectedProfileID, apiKey: apiKey, from: from)
            isAuthenticated = true
        } catch {
            if profiles.isEmpty { isAuthenticated = false }
            errorMessage = error.localizedDescription
        }
    }

    public func saveAPIKey(_ value: String) async {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try credentials.deleteAPIKey()
                apiKey = nil
                profiles = []
                selectedProfileID = nil
                snapshot = nil
                isAuthenticated = false
            } else {
                try credentials.saveAPIKey(trimmed)
                apiKey = trimmed
                profiles = []
                selectedProfileID = nil
                await refresh()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func selectProfile(id: String) async {
        guard profiles.contains(where: { $0.id == id }) else { return }
        selectedProfileID = id
        await refresh()
    }
}
