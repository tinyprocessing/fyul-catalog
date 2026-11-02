import XCTest

final class ProductListUITests: UITestCase {
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

    func testAnnouncementFromRemoteConfig() {
        let app = launch("catalog", ["-announcement", "Prices update tonight"])

        XCTAssertTrue(element(app, List.announcementBanner).waitForExistence(timeout: 5))
    }
}
