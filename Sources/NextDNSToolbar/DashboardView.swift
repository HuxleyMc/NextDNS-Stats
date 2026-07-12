import AppKit
import SwiftUI
import NextDNSToolbarCore

struct DashboardView: View {
    @ObservedObject var store: DashboardStore
    @State private var section = Section.overview
    @State private var showingSettings = false

    enum Section: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case logs = "Logs"
        case analytics = "Analytics"
        var id: Self { self }
    }

    var body: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            VStack(spacing: 10) {
                header
                    .glassPanel(cornerRadius: 18, tint: .blue.opacity(0.08))
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                if !store.isAuthenticated && store.profiles.isEmpty {
                    setupPrompt
                } else {
                    Picker("Section", selection: $section) {
                        ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .padding(5)
                    .glassPanel(cornerRadius: 12)
                    .padding(.horizontal, 10)

                    Group {
                        switch section {
                        case .overview: overview
                        case .logs: logs
                        case .analytics: analytics
                        }
                    }
                }

                footer
                    .glassPanel(cornerRadius: 13)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
        }
        .frame(width: 420, height: 640)
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store, isPresented: $showingSettings)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatusPill(
                    title: store.connection.isConnected ? "Connected" : "Not connected",
                    detail: store.connection.protocolName,
                    isPositive: store.connection.isConnected
                )
                Spacer()
                if store.isLoading { ProgressView().controlSize(.small) }
                Button { Task { await store.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .glassControl()
                .help("Refresh now")
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .glassControl()
                .help("Settings")
            }

            if !store.profiles.isEmpty {
                Picker("Profile", selection: profileBinding) {
                    ForEach(store.profiles) { Text($0.name).tag(Optional($0.id)) }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
    }

    private var profileBinding: Binding<String?> {
        Binding(
            get: { store.selectedProfileID },
            set: { id in
                guard let id else { return }
                Task { await store.selectProfile(id: id) }
            }
        )
    }

    private var setupPrompt: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Connect your NextDNS account")
                .font(.headline)
            Text("Add the API key from the bottom of your NextDNS account page to load profiles, analytics, and logs.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 300)
            Button("Add API Key") { showingSettings = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .glassPanel(cornerRadius: 22, tint: .blue.opacity(0.1))
        .padding(.horizontal, 10)
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    MetricCard(title: "Requests", value: formatted(store.snapshot?.totalRequests), icon: "network")
                    MetricCard(title: "Blocked", value: formatted(store.snapshot?.blockedRequests), icon: "hand.raised.fill", tint: .red)
                    MetricCard(title: "Block rate", value: percent(store.snapshot?.blockRate), icon: "chart.pie.fill", tint: .orange)
                }

                sectionTitle("Most blocked")
                if let domains = store.snapshot?.blockedDomains, !domains.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(domains) { domain in
                            MetricRow(label: domain.domain, value: formatted(domain.queries), iconDomain: domain.iconDomain)
                            if domain.id != domains.last?.id { Divider() }
                        }
                    }
                    .panelStyle()
                } else {
                    EmptyState(text: "No blocked domains in the last 24 hours")
                }

                sectionTitle("Recent activity")
                compactLogs(limit: 6)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
        }
    }

    private var logs: some View {
        ScrollView {
            VStack(spacing: 0) {
                if store.snapshot?.logs.isEmpty != false {
                    EmptyState(text: "No recent logs")
                } else {
                    compactLogs(limit: nil)
                    if store.snapshot?.nextLogCursor != nil {
                        Button {
                            Task { await store.loadMoreLogs() }
                        } label: {
                            HStack(spacing: 7) {
                                if store.isLoadingMoreLogs {
                                    ProgressView().controlSize(.small)
                                }
                                Text(store.isLoadingMoreLogs ? "Loading…" : "Load more")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.isLoadingMoreLogs)
                        .padding(.top, 12)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
        }
    }

    private var analytics: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("Protocols")
                MetricBreakdown(metrics: store.snapshot?.protocols ?? [])
                sectionTitle("Devices")
                MetricBreakdown(metrics: store.snapshot?.devices ?? [])
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private func compactLogs(limit: Int?) -> some View {
        let allLogs = store.snapshot?.logs ?? []
        let entries = limit.map { Array(allLogs.prefix($0)) } ?? allLogs
        if entries.isEmpty {
            EmptyState(text: "No recent logs")
        } else {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    LogRow(entry: entry)
                    if entry.id != entries.last?.id { Divider() }
                }
            }
            .panelStyle()
        }
    }

    private var footer: some View {
        HStack {
            if let fetchedAt = store.snapshot?.fetchedAt {
                Text("Updated \(fetchedAt, style: .relative) ago")
            } else {
                Text("24-hour window")
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.headline)
    }

    private func formatted(_ value: Int?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.notation(.compactName))
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(1)))
    }
}
