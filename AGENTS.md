# Notes for coding agents

## Commands
- `make build`, `make test` (unit), `make ui-test` (XCUITest, stubbed), `make maestro` (needs a booted simulator), `make lint` / `make format`.
- Override the simulator with `IPHONE="iPhone 17"` or `IPAD="..."`; `xcrun simctl list devices available` shows names.
- `make run SCENARIO=pageFails` launches the app with a stubbed backend. Scenarios: `StubScenario` in `CatalogCore/Stubs`.
- `.mcp.json` registers Xcode's MCP server (`xcrun mcpbridge`) for builds, previews and diagnostics while Xcode is open.
- Changing `project.yml` → run `make project` and commit the regenerated `Catalog.xcodeproj`.
- New screen or area → `scripts/new-feature.sh <Name>` (creates `<Name>Feature`, registers it in Package.swift and project.yml).
- Debugging → `make logs` (os.Logger, subsystem `com.tinyprocessing.catalog`); add a `Log.<category>` line where behaviour branches.
- UI tests have a 60 s per-test limit. A test that hangs or flakes gets deleted, not retried.

## Layout
- `App/`: composition root only. `AppEnvironment` picks live or stubbed implementations.
- `Packages/CatalogKit/Sources/`
  - `CatalogCore`: config, models, networking (`HTTPClient` → `RetryingHTTPClient`), `ProductService`, remote config, connectivity, stubs (DEBUG only).
  - `DesignSystem`: tokens (`Spacing`, `Radius`, `Metrics`, `Palette`, `Typography`) and generic components. No feature strings.
  - `ProductsFeature`: list and detail screens and their `@Observable` models.
  - `CatalogAccessibility`: identifiers shared by the app, XCUITest and Maestro.
- `Tests/CatalogTests`: Swift Testing. `Tests/CatalogUITests`: XCUITest. `maestro/flows`: Maestro.
- `remote-config/flags.json`: the remote config the app fetches (`REMOTE_CONFIG_URL` in `Config/Base.xcconfig`).

## Rules
- No third-party dependencies.
- No literals in views: spacing, sizes, colors and fonts come from `DesignSystem`; tunables from `AppConfig`.
- Every user-facing string goes through `L10n` with a key in `Localizable.xcstrings`, in both `en` and `es`.
- Every interactive or asserted element gets an identifier in `AccessibilityID`; container views use `.accessibilityElement(children: .contain)` before an identifier so children keep theirs.
- Models are `@MainActor @Observable`, take dependencies through `CatalogDependencies`, and never touch `URLSession`.
- Network work that can be superseded must check the list model's `generation` (see `ProductListModel`).
- New behaviour comes with a unit test; a new screen state comes with a UI test or Maestro flow.
- Comments explain why, not what. Swift 6 strict concurrency, warnings are errors.
- Before finishing: `make lint test ui-test`.
