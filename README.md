# Catalog

A first version of a product catalog for merchants who run their business from their phone.
It is built on the [DummyJSON Products API](https://dummyjson.com/docs/products) with SwiftUI and has no third-party dependencies.

```sh
open Catalog.xcodeproj      # Run the "Catalog" scheme on any iPhone or iPad simulator
make test                   # unit tests
make ui-test                # XCUITest with stubbed backend + accessibility audit
make maestro                # Maestro flows (stubbed); `make maestro-live` hits the real API
make help                   # everything else
```

## What the merchant gets

- **List**: thumbnail, price with discount, stock level and rating. It supports search, a category filter, sorting (including *low stock first*) and pull to refresh, and the next page loads before you reach the end.
- **Detail**: the list summary appears at once, then the full product loads (gallery, SKU, stock, minimum order, shipping, warranty, returns, reviews).
- **iPhone and iPad**: `NavigationSplitView`. It is a sidebar with detail on iPad and a stack on iPhone. Rows switch to a vertical layout at accessibility text sizes.
- **English and Spanish**, with plurals, from String Catalogs.

## Main decisions

| Decision | Considered instead | Why |
|---|---|---|
| Native `@Observable` models with injected protocols | TCA, which you use | The boundaries map one to one onto TCA (state, actions as methods, dependencies as a struct). In a small app the library would add more concepts than it removes. |
| Local Swift package with `CatalogCore`, `DesignSystem`, `ProductsFeature` and `CatalogAccessibility` | One target | Each layer compiles and tests alone, the feature can't reach `URLSession`, and the app target is only a composition root. |
| Retry as a decorator (`RetryingHTTPClient`) | Retry inside view models | Exponential backoff with jitter, only for idempotent requests on transient errors (timeouts, 5xx, 429), and `Retry-After` is respected. One place, and fully unit tested. |
| A generation counter in the list model | Hoping cancellation arrives in time | A slow response for the previous query or sort can never overwrite the current results. |
| Remote config as a static JSON file (`remote-config/flags.json`) | Firebase | It needs no SDK. The app uses the last good config, then bundled defaults. Every key falls back on its own, and a failed fetch never downgrades flags. |
| Stock thresholds from remote config | The API's `availabilityStatus` text | What counts as *low* is a business decision, not a backend label. |
| XcodeGen `project.yml`, with the generated project committed | Hand-edited project | Clean diffs. Opening the project needs no extra tools. |

## Edge cases handled

- **Network failures**:
  - A first-load failure gives a full-screen error with retry.
  - A failed next page keeps the products and shows an inline retry.
  - A failed refresh keeps the content and shows a banner.
  - When the device goes offline and comes back, failed loads reload by themselves (`NWPathMonitor`).
- **Slow responses**: a pull to refresh racing a page load, and fast typing in search (debounced, trimmed, minimum length), cannot show results for the wrong query.
- **Data**:
  - Duplicates between offset pages are removed.
  - A page shorter than `total` promises ends pagination.
  - Broken image URLs don't fail a product.
  - A product deleted after the list loaded shows *no longer available* instead of an error.
- **Remote config**: if config withdraws the sort option that is currently selected, the list falls back to *featured*.

## Tests

- **Unit tests** (Swift Testing, 43 tests, no network): the retry policy and client, status mapping, decoding of a real payload, remote config, and list and detail models. The list tests control the order of responses with continuations, so the race conditions above are tested, not just described.
- **XCUITest** (7 tests): browsing, error → retry, page failure → retry, empty search, removed product, the remote announcement, and `performAccessibilityAudit()`.
- **Maestro** (7 flows): the same scenarios, plus Spanish and one smoke test against the live API.
- **Shared IDs**: all three use one set of identifiers from `CatalogAccessibility`. The stubbed scenarios are chosen with `-uiTestScenario <name>`; see `StubScenario`.

## Left out on purpose

- **Offline storage**: products are not saved to disk. Next I'd cache the first page per query (SwiftData or a file) so the app opens with content.
- **Image pipeline**: images go through `AsyncImage` + `URLCache`. With real catalogs I'd add downsampling and prefetching.
- **Snapshot tests**: they need a third-party library; the accessibility audit and UI tests cover the visible states instead.
- **Analytics, editing, CI**: the API cannot persist writes. CI is one `make test ui-test` job once a runner with this Xcode is available.

## How I'd know it works for merchants

- **Speed**: time to first product on screen, p50 and p95, by network type.
- **Finding products**: search success, meaning searches that end in opening a product, and how often people see the empty search state.
- **Usefulness**: list → detail open rate. I'd also watch how often the low-stock sort or filters are used, which tells me if stock is what merchants come for.
- **Reliability**:
  - error-state views per session and retry success rate;
  - crash-free sessions;
  - share of sessions with a remote config fetch failure.

## How I used AI

I worked with Claude Code as a pair. I set the requirements (architecture, edge cases, accessibility, localization, remote config, testability) and reviewed every change. The agent wrote most of the code, the tests and the flows. Places where I changed or rejected its output:

- **`Retry-After`**: the first version capped a server's `Retry-After` at our maximum delay, which would hit a rate-limited server too early. Now we give up instead.
- **Accessibility identifiers**: an identifier on a container view overwrote the identifiers of its children, so the retry button was not reachable. The UI test caught it; containers now use `.accessibilityElement(children: .contain)`.
- **Contrast**: the accessibility audit failed on the status badges. The palette now has darker light-mode variants.
- **Selected row on iPad**: screenshots showed the brand and badges disappearing on the selected sidebar row. It is fixed with `backgroundProminence` instead of hard-coded colors.
- **Naming**: a design token enum named `Layout` collided with SwiftUI's `Layout` protocol and was renamed.

`AGENTS.md` describes the project for coding agents, and `.mcp.json` connects them to Xcode's own MCP server (`xcrun mcpbridge`). In the call I'll extend the app with the same setup.
