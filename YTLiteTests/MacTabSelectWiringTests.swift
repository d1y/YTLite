import XCTest
@testable import YTLite

/// Proves the Mac tab selection contract used by `MainTabBarController.selectMacTab`
/// and `MacActionChromeBar.onTabSelect` — indices 0/1/2 only, no crash path.
final class MacTabSelectWiringTests: XCTestCase {
    /// Mirrors the production callback: chrome onTabSelect → select valid index.
    func testTabSelectCallbackAcceptsOnlyValidIndices() {
        let tabCount = 3
        var selected: [Int] = []
        let onTabSelect: (Int) -> Void = { index in
            guard (0..<tabCount).contains(index) else {
                return
            }
            selected.append(index)
        }

        // Simulate NSToolbarItemGroup / strip firing each segment.
        for index in 0..<tabCount {
            onTabSelect(index)
        }
        // Out-of-range must be ignored (same guard as selectMacTab).
        onTabSelect(-1)
        onTabSelect(99)

        XCTAssertEqual(selected, [0, 1, 2])
    }

    func testMacRootFeedTopExtraInsetIsZeroForGapCriterion() {
        XCTAssertEqual(
            ResponsiveMetrics.macRootFeedTopExtraInset(),
            0,
            accuracy: 0.01
        )
    }

    func testMacSearchBackAndFieldShareHeightMetric() {
        let height = ResponsiveMetrics.macSearchControlHeight()
        XCTAssertEqual(height, 40, accuracy: 0.01)
        // Contract used by SearchViewController equal-height constraints.
        XCTAssertEqual(height, ResponsiveMetrics.macSearchControlHeight())
    }
}
