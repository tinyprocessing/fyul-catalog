import XCTest

final class ProductDetailUITests: UITestCase {
    func testBrowseAndOpenProduct() {
        let app = launch("catalog")

        let row = element(app, List.row(1))
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(element(app, Detail.title).waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, Detail.reviews).waitForExistence(timeout: 5))
    }

    func testRemovedProductShowsUnavailable() {
        let app = launch("productRemoved")

        let row = element(app, List.row(2))
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(element(app, Detail.unavailable).waitForExistence(timeout: 5))
    }
}
