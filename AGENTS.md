# Repository Guidelines

## Project Structure & Module Organization

This repository is a Swift Package for a menu-bar-only macOS app. `Package.swift` defines two targets:

- `Sources/NextDNSToolbar/` contains the SwiftUI app, menu-bar controller, settings, dashboard, and reusable views.
- `Sources/NextDNSToolbarCore/` contains API access, models, credential storage, dashboard state, and favicon mapping logic.
- `Tests/NextDNSToolbarCoreTests/` contains XCTest coverage for the core target.
- `Resources/` holds the app `Info.plist` and code-signing requirement; `IconDomainMappings.json` provides editable service-to-icon mappings.
- `scripts/` builds and installs the packaged `.app`; generated artifacts belong under `build/` or `.build/`.

## Build, Test, and Development Commands

Run commands from the repository root on macOS 14+ with Xcode 16+:

```sh
swift build                    # compile a debug build
swift test                     # run all XCTest suites
swift test --filter NextDNSClientTests
./scripts/build-app.sh         # create build/NextDNS Stats.app
./scripts/install-app.sh       # rebuild, install in /Applications, and launch
```

The install script replaces the existing app and stops a running `NextDNSStats` process, so use it deliberately.

## Coding Style & Naming Conventions

Follow the existing Swift style: four-space indentation, trailing commas in multiline literals and calls, and one primary type per focused file. Use `UpperCamelCase` for types, `lowerCamelCase` for members, and descriptive protocol names such as `NextDNSClientProtocol`. Keep networking, persistence, and state logic in `NextDNSToolbarCore`; keep presentation code in the executable target. No formatter or linter is configured, so match neighboring code and review `git diff --check` before submitting.

## Testing Guidelines

Use XCTest and place tests in `Tests/NextDNSToolbarCoreTests/`. Name files after the subject (`DashboardStoreTests.swift`) and methods as behavior statements beginning with `test`, for example `testFetchLogsSendsCursorAndDecodesNextPage`. Stub network traffic rather than calling live NextDNS endpoints. Add focused tests for API decoding, errors, cancellation, profile switching, and mapping fallbacks. Run `swift test` before opening a pull request.

## Commit & Pull Request Guidelines

History follows Conventional Commit-style subjects such as `feat:`, `fix:`, `style:`, and scoped forms like `chore(icons):`. Keep commits small, imperative, and single-purpose. Pull requests should explain user-visible behavior, list verification commands, and link relevant issues. Include screenshots for popover, settings, or other visual changes. Never commit API keys, Keychain exports, or generated build artifacts.
