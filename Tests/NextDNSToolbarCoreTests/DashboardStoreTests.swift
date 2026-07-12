import XCTest
@testable import NextDNSToolbarCore

@MainActor
final class DashboardStoreTests: XCTestCase {
    func testRefreshWithoutAPIKeyOnlyChecksConnection() async {
        let client = FakeClient()
        let credentials = MemoryCredentials(value: nil)
        let store = DashboardStore(client: client, credentials: credentials)

        await store.refresh()

        XCTAssertTrue(store.connection.isConnected)
        let counts = await client.counts()
        XCTAssertEqual(counts.profiles, 0)
        XCTAssertEqual(counts.dashboardIDs, [])
    }

    func testSaveAPIKeyLoadsProfilesAndFirstDashboard() async throws {
        let client = FakeClient()
        let credentials = MemoryCredentials(value: nil)
        let store = DashboardStore(client: client, credentials: credentials)

        await store.saveAPIKey("new-key")

        XCTAssertEqual(try credentials.loadAPIKey(), "new-key")
        XCTAssertEqual(store.profiles.map(\.name), ["Home", "Family"])
        XCTAssertEqual(store.selectedProfileID, "home")
        XCTAssertEqual(store.snapshot?.totalRequests, 100)
        XCTAssertTrue(store.isAuthenticated)
    }

    func testSelectingAnotherProfileRefreshesItsDashboard() async {
        let client = FakeClient()
        let store = DashboardStore(client: client, credentials: MemoryCredentials(value: "key"))
        await store.refresh()

        await store.selectProfile(id: "family")

        XCTAssertEqual(store.selectedProfileID, "family")
        let counts = await client.counts()
        XCTAssertEqual(counts.dashboardIDs.last, "family")
    }

    func testStartRefreshingImmediatelyRefreshesAndStopCancelsPolling() async throws {
        let client = FakeClient()
        let store = DashboardStore(
            client: client,
            credentials: MemoryCredentials(value: nil),
            refreshInterval: .milliseconds(20)
        )

        store.startRefreshing()
        try await Task.sleep(for: .milliseconds(75))
        store.stopRefreshing()
        let stoppedCount = await client.counts().connections
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertGreaterThanOrEqual(stoppedCount, 3)
        let finalCount = await client.counts().connections
        XCTAssertEqual(finalCount, stoppedCount)
    }

    func testFailedRefreshKeepsExistingSnapshotAndShowsError() async {
        let client = FakeClient()
        let store = DashboardStore(client: client, credentials: MemoryCredentials(value: "key"))
        await store.refresh()
        await client.setDashboardError(NextDNSClientError.api("Temporary failure"))

        await store.refresh()

        XCTAssertEqual(store.snapshot?.totalRequests, 100)
        XCTAssertEqual(store.errorMessage, "Temporary failure")
    }
}

private actor FakeClient: NextDNSClientProtocol {
    var profileRequests = 0
    var dashboardProfileIDs: [String] = []
    var connectionRequests = 0
    private var dashboardError: Error?

    func counts() -> (profiles: Int, dashboardIDs: [String], connections: Int) {
        (profileRequests, dashboardProfileIDs, connectionRequests)
    }

    func setDashboardError(_ error: Error?) { dashboardError = error }

    func fetchProfiles(apiKey: String) async throws -> [Profile] {
        profileRequests += 1
        return [Profile(id: "home", name: "Home"), Profile(id: "family", name: "Family")]
    }

    func fetchDashboard(profileID: String, apiKey: String, from: Date) async throws -> DashboardSnapshot {
        dashboardProfileIDs.append(profileID)
        if let dashboardError { throw dashboardError }
        return DashboardSnapshot(
            totalRequests: 100,
            blockedRequests: 20,
            allowedRequests: 5,
            blockedDomains: [],
            protocols: [],
            devices: [],
            logs: []
        )
    }

    func fetchConnectionStatus() async throws -> ConnectionStatus {
        connectionRequests += 1
        return ConnectionStatus(status: "ok", protocolName: "DOH", profileID: "home")
    }
}

private final class MemoryCredentials: CredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    init(value: String?) { self.value = value }

    func loadAPIKey() throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func saveAPIKey(_ apiKey: String) throws {
        lock.lock(); defer { lock.unlock() }
        value = apiKey
    }

    func deleteAPIKey() throws {
        lock.lock(); defer { lock.unlock() }
        value = nil
    }
}
