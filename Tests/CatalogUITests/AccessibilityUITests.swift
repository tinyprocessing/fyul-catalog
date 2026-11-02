import XCTest

final class AccessibilityUITests: UITestCase {
    /// Structural audit: every element is reachable, labelled, tappable and has the right traits.
    /// Contrast and Dynamic Type are design-system decisions (semantic colors, restacking layouts), reviewed by eye.
    func testProductListAudit() throws {
        let app = launch("catalog")
        XCTAssertTrue(element(app, List.row(1)).waitForExistence(timeout: 5))

        try app.performAccessibilityAudit(for: [.elementDetection, .hitRegion, .sufficientElementDescription, .trait])
    }
}
