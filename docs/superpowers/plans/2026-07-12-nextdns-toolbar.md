# NextDNS Stats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu-bar app that monitors current NextDNS connectivity and displays 24-hour totals, blocked domains, analytics, and recent logs for multiple profiles.

**Architecture:** A Swift Package produces a SwiftUI/AppKit executable and tests. `NextDNSClient` owns HTTP decoding, `DashboardStore` owns refresh state, `CredentialStore` persists the API key in Keychain, and a menu-bar popover renders profile selection, metrics, analytics, and logs. A packaging script wraps the release executable in a standard `.app` bundle.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation URLSession, Security/Keychain, Swift Testing, Swift Package Manager; macOS 14+.

## Global Constraints

- Native menu-bar-only app with no Dock icon.
- Support multiple NextDNS profiles returned by the authenticated account.
- Default analytics window is the previous 24 hours.
- Refresh every 30 seconds while the popover is open and once whenever it opens.
- “Connected” means this Mac is currently resolving through NextDNS; API authentication is shown separately.
- Store the API key in macOS Keychain and never in preferences or source files.

---

### Task 1: API Models and Client

**Files:**
- Create: `Package.swift`
- Create: `Sources/NextDNSToolbarCore/Models.swift`
- Create: `Sources/NextDNSToolbarCore/NextDNSClient.swift`
- Test: `Tests/NextDNSToolbarCoreTests/NextDNSClientTests.swift`

**Interfaces:**
- Produces: `NextDNSClient.fetchProfiles(apiKey:)`, `fetchDashboard(profileID:apiKey:from:)`, and `fetchConnectionStatus()`.

- [ ] Write URL-protocol-backed tests proving headers, profile decoding, 24-hour analytics aggregation, blocked-domain filtering, recent-log decoding, and connection-status decoding.
- [ ] Run `swift test --filter NextDNSClientTests` and verify failure because the production types do not exist.
- [ ] Implement codable response envelopes, models, request construction, concurrent dashboard requests, and typed errors.
- [ ] Run `swift test --filter NextDNSClientTests` and verify all tests pass.

### Task 2: Credentials and Dashboard State

**Files:**
- Create: `Sources/NextDNSToolbarCore/CredentialStore.swift`
- Create: `Sources/NextDNSToolbarCore/DashboardStore.swift`
- Test: `Tests/NextDNSToolbarCoreTests/DashboardStoreTests.swift`

**Interfaces:**
- Consumes: `NextDNSClientProtocol` and Task 1 models.
- Produces: `DashboardStore.startRefreshing()`, `stopRefreshing()`, `refresh()`, `saveAPIKey(_:)`, and `selectProfile(id:)`.

- [ ] Write actor-safe fake-client tests for initial state, profile selection, refresh, error preservation, and 30-second refresh lifecycle.
- [ ] Run the dashboard tests and verify failure because the store does not exist.
- [ ] Implement Keychain access behind `CredentialStoring` plus observable dashboard orchestration.
- [ ] Run all tests and verify they pass.

### Task 3: Native Menu-Bar Interface

**Files:**
- Create: `Sources/NextDNSToolbar/App.swift`
- Create: `Sources/NextDNSToolbar/MenuBarController.swift`
- Create: `Sources/NextDNSToolbar/DashboardView.swift`
- Create: `Sources/NextDNSToolbar/SettingsView.swift`
- Create: `Sources/NextDNSToolbar/Components.swift`

**Interfaces:**
- Consumes: `DashboardStore`.
- Produces: menu-bar item and popover with status, profile picker, summary metrics, blocked-domain ranking, analytics breakdown, logs, settings, refresh, and quit actions.

- [ ] Add a compile-time smoke test target dependency so UI compilation is part of `swift build`.
- [ ] Run `swift build` and capture missing-entry-point failure.
- [ ] Implement the compact SwiftUI popover and AppKit status-item lifecycle, starting refresh on open and stopping it on close.
- [ ] Run `swift build` and `swift test` and verify both pass without warnings.

### Task 4: App Bundle, Documentation, and Runtime Verification

**Files:**
- Create: `scripts/build-app.sh`
- Create: `Resources/Info.plist`
- Create: `README.md`

**Interfaces:**
- Consumes: release executable.
- Produces: `build/NextDNS Stats.app`.

- [ ] Build the release executable and assemble a correctly structured LSUIElement app bundle.
- [ ] Document build, launch, API-key setup, privacy behavior, and current limitations.
- [ ] Run `swift test`, `swift build -c release`, `scripts/build-app.sh`, `plutil -lint`, `codesign --verify --deep --strict`, and launch/inspect/terminate the app.
- [ ] Verify the process stays running, appears without a Dock activation policy, and performs no authenticated request before credentials are supplied.

## Self-Review

- Every requested surface maps to a dashboard endpoint or explicit connection probe.
- Profile selection, credential protection, open-only polling, errors, and packaging are included.
- No placeholders or deferred implementation items remain.
