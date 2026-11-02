import CatalogAccessibility
import XCTest

/// Base for UI tests. Runs against `StubProductService`: no network, deterministic data.
/// One class per area.
@MainActor
class UITestCase: XCTestCase {
    typealias List = AccessibilityID.ProductList
    typealias Detail = AccessibilityID.ProductDetail

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func launch(_ scenario: String, _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestScenario", scenario, "-AppleLanguages", "(en)"] + extra
        app.launch()
        return app
    }

    func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
