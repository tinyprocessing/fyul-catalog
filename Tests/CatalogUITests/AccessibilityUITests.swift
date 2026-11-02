import XCTest

final class AccessibilityUITests: UITestCase {
    func testProductListAudit() throws {
        let app = launch("catalog")
        XCTAssertTrue(element(app, List.row(1)).waitForExistence(timeout: 5))

        // Contrast findings without an element come from cards blurred under the system search bar.
        try app.performAccessibilityAudit { issue in
            issue.auditType == .contrast && issue.element == nil
        }
    }
}
