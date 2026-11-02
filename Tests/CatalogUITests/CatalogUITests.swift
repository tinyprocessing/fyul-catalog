import CatalogAccessibility
import XCTest

/// Runs against `StubProductService`: no network, deterministic data. See `StubScenario` for scenarios.
@MainActor
final class CatalogUITests: XCTestCase {
    private typealias List = AccessibilityID.ProductList
    private typealias Detail = AccessibilityID.ProductDetail

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String, _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestScenario", scenario, "-AppleLanguages", "(en)"] + extra
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func testBrowseAndOpenProduct() {
        let app = launch("catalog")

        let row = element(app, List.row(1))
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(element(app, Detail.title).waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, Detail.reviews).waitForExistence(timeout: 5))
    }

    func testServerErrorRecoversAfterRetry() {
        let app = launch("recoversAfterRetry")

        let retry = element(app, List.retryButton)
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()

        XCTAssertTrue(element(app, List.row(1)).waitForExistence(timeout: 5))
    }

    func testFailedPageKeepsProductsAndRetries() {
        let app = launch("pageFails")
        XCTAssertTrue(element(app, List.row(1)).waitForExistence(timeout: 5))

        let pageRetry = element(app, List.pageRetryButton)
        let list = element(app, List.list)
        for _ in 0..<8 where !pageRetry.exists {
            list.swipeUp()
        }
        XCTAssertTrue(pageRetry.waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, List.row(20)).exists)
        pageRetry.tap()

        XCTAssertTrue(element(app, List.row(21)).waitForExistence(timeout: 5))
    }

    func testSearchWithoutResultsShowsEmptyState() {
        let app = launch("catalog")
        XCTAssertTrue(element(app, List.row(1)).waitForExistence(timeout: 5))

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("zzzz")

        XCTAssertTrue(element(app, List.emptyState).waitForExistence(timeout: 5))
    }

    func testRemovedProductShowsUnavailable() {
        let app = launch("productRemoved")

        let row = element(app, List.row(2))
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(element(app, Detail.unavailable).waitForExistence(timeout: 5))
    }

    func testAnnouncementFromRemoteConfig() {
        let app = launch("catalog", ["-announcement", "Prices update tonight"])

        XCTAssertTrue(element(app, List.announcementBanner).waitForExistence(timeout: 5))
    }

    func testAccessibilityAudit() throws {
        let app = launch("catalog")
        XCTAssertTrue(element(app, List.row(1)).waitForExistence(timeout: 5))

        // Contrast findings without an element come from rows blurred under the system search bar.
        try app.performAccessibilityAudit { issue in
            print("AUDIT", issue.compactDescription, issue.element?.label ?? "-", issue.element?.identifier ?? "-")
            return issue.auditType == .contrast && issue.element == nil
        }
    }
}
