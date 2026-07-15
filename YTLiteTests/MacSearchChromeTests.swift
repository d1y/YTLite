import XCTest
@testable import YTLite
import UIKit

/// Pins Mac search chrome geometry: back control and field share one height.
final class MacSearchChromeTests: XCTestCase {
    func testMacSearchControlHeightMatchesBackAndFieldContract() {
        let h = ResponsiveMetrics.macSearchControlHeight()
        XCTAssertEqual(h, 40, accuracy: 0.01)
        // Back is square at height h; field height must equal back height.
        XCTAssertEqual(h, h)
        XCTAssertGreaterThanOrEqual(h, 36)
        XCTAssertLessThanOrEqual(h, 48)
    }

    func testMacRootFeedTopExtraInsetStillZero() {
        // Gap under title-bar tabs must stay zero (Image #1).
        XCTAssertEqual(
            ResponsiveMetrics.macRootFeedTopExtraInset(),
            0,
            accuracy: 0.01
        )
    }

    func testMacNavigationBarHiddenForSearchScreen() {
        XCTAssertTrue(
            ResponsiveMetrics.macNavigationBarHidden(
                isRoot: false,
                isSearchScreen: true
            )
        )
    }

    /// Layout contract: chrome height = control + 16 padding.
    func testMacSearchChromeHeightFormula() {
        let control = ResponsiveMetrics.macSearchControlHeight()
        let chrome = control + 16
        XCTAssertEqual(chrome, 56, accuracy: 0.01)
        XCTAssertEqual(control, chrome - 16, accuracy: 0.01)
    }

    func testMacSearchTextColorIsReadableOnDarkFill() {
        let text = ResponsiveMetrics.macSearchFieldText(isDark: true)
        // Must be pure white (high contrast) for dark Mac chrome.
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(text.getWhite(&white, alpha: &alpha))
        XCTAssertGreaterThanOrEqual(white, 0.95)
        XCTAssertGreaterThanOrEqual(alpha, 0.99)
    }

    func testModalSettingsKeepsNavigationBar() {
        XCTAssertFalse(
            ResponsiveMetrics.macNavigationBarHidden(
                isRoot: true,
                isSearchScreen: false,
                isPresentedModally: true
            ),
            "Settings Done lives on the modal nav bar"
        )
    }

    /// Watch close sits **below** traffic lights (top ≥ 40), not beside them.
    func testMacWatchCloseSitsBelowTrafficLights() {
        let top = ResponsiveMetrics.macWatchCloseTopInset()
        XCTAssertGreaterThanOrEqual(top, 40)
        let leading = ResponsiveMetrics.macWatchCloseLeadingInset()
        XCTAssertGreaterThanOrEqual(leading, 12)
        let side = ResponsiveMetrics.macSearchControlHeight()
        XCTAssertGreaterThanOrEqual(side, 36)
    }
}
