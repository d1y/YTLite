import XCTest
@testable import YTLite
import UIKit

/// Exercises the **real** `MacTopTabStrip.hitTest` path (no UIView swizzle).
/// Note: production Mac tabs now live in `NSToolbar` via `MacActionChromeBar`
/// (title-bar hits are reliable). This strip remains unit-testable chrome
/// infrastructure and a possible non-toolbar fallback.
final class MacTopTabStripTests: XCTestCase {
    private func makeLaidOutStrip() -> MacTopTabStrip {
        let strip = MacTopTabStrip(
            titles: ["Home", "Subscriptions", "Library"]
        )
        strip.frame = CGRect(x: 0, y: 0, width: 900, height: 48)
        // Force Auto Layout of centered pill.
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 900, height: 200))
        host.addSubview(strip)
        NSLayoutConstraint.activate([
            strip.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            strip.topAnchor.constraint(equalTo: host.topAnchor),
            strip.heightAnchor.constraint(
                equalToConstant: ResponsiveMetrics.macTopTabStripHeight()
            )
        ])
        host.layoutIfNeeded()
        strip.layoutIfNeeded()
        return strip
    }

    func testHitTestOutsidePillReturnsNilWithoutCrash() {
        let strip = makeLaidOutStrip()
        // Far left of full-width strip — empty pass-through area.
        let hit = strip.hitTest(CGPoint(x: 8, y: 24), with: nil)
        XCTAssertNil(hit)
    }

    func testHitTestCenterOfPillReturnsInteractiveView() {
        let strip = makeLaidOutStrip()
        let pill = strip.tabBar
        // Center of the glass pill in strip coordinates.
        let centerInStrip = strip.convert(
            CGPoint(x: pill.bounds.midX, y: pill.bounds.midY),
            from: pill
        )
        let hit = strip.hitTest(centerInStrip, with: nil)
        XCTAssertNotNil(
            hit,
            "Center of tab pill must hit a control (not nil / not crash)"
        )
        // Must be inside the pill hierarchy, not the strip itself.
        XCTAssertTrue(
            hit === pill || hit?.isDescendant(of: pill) == true
        )
    }

    func testTabIndexResolvesAllThreeSegments() {
        let strip = makeLaidOutStrip()
        let pill = strip.tabBar
        // Three equal segments: sample left / mid / right thirds of pill.
        let samples: [(xFraction: CGFloat, expected: Int)] = [
            (0.15, 0),
            (0.50, 1),
            (0.85, 2)
        ]
        for sample in samples {
            let pInPill = CGPoint(
                x: pill.bounds.width * sample.xFraction,
                y: pill.bounds.midY
            )
            let pInStrip = strip.convert(pInPill, from: pill)
            let index = strip.tabIndex(atStripPoint: pInStrip)
            XCTAssertEqual(
                index,
                sample.expected,
                "Fraction \(sample.xFraction) should map to tab \(sample.expected)"
            )
        }
    }

    func testOnSelectFiresForEachIndexWithoutCrash() {
        let strip = makeLaidOutStrip()
        var chosen: [Int] = []
        strip.onSelect = { chosen.append($0) }
        for index in 0..<3 {
            strip.select(index: index, notify: true)
        }
        XCTAssertEqual(chosen, [0, 1, 2])
    }

    func testHitTestDoesNotRecurseIntoUIViewSwizzle() {
        // Regression: global UIView.hitTest swizzle SIGSEGV'd on UIButton.hitTest.
        // Calling hitTest repeatedly must stay stable.
        let strip = makeLaidOutStrip()
        let pill = strip.tabBar
        let center = strip.convert(
            CGPoint(x: pill.bounds.midX, y: pill.bounds.midY),
            from: pill
        )
        for _ in 0..<50 {
            _ = strip.hitTest(center, with: nil)
            _ = strip.hitTest(CGPoint(x: 4, y: 4), with: nil)
        }
        // Also exercise nested UIButton.hitTest directly on a live button.
        if let stack = pill.subviews.compactMap({ $0 as? UIStackView }).first,
           let button = stack.arrangedSubviews.first as? UIButton {
            let point = CGPoint(x: button.bounds.midX, y: button.bounds.midY)
            XCTAssertNotNil(button.hitTest(point, with: nil))
        }
    }

    /// Skeptic: prove hitTest → button for tabs 0/1/2 without SIGSEGV,
    /// then `sendActions` fires `onSelect` with those indices (real wiring).
    func testHitTestAndTapSelectsEachTabIndexWithoutCrash() {
        let strip = makeLaidOutStrip()
        let pill = strip.tabBar
        var chosen: [Int] = []
        strip.onSelect = { chosen.append($0) }

        guard let stack = pill.subviews.compactMap({ $0 as? UIStackView }).first
        else {
            XCTFail("MacTopTabBar must host a UIStackView of tab buttons")
            return
        }
        let buttons = stack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(buttons.count, 3, "Home / Subscriptions / Library")

        for expected in 0..<3 {
            let button = buttons[expected]
            XCTAssertEqual(button.tag, expected)

            // Real hitTest path: strip → pill → button (no UIView swizzle).
            let centerInButton = CGPoint(
                x: button.bounds.midX,
                y: button.bounds.midY
            )
            let inStrip = strip.convert(centerInButton, from: button)
            let hit = strip.hitTest(inStrip, with: nil)
            XCTAssertNotNil(hit, "tab \(expected) hitTest must not be nil/crash")
            XCTAssertTrue(
                hit === button || hit?.isDescendant(of: button) == true
                    || hit?.isDescendant(of: pill) == true,
                "tab \(expected) hit must land in pill/button hierarchy"
            )

            // Direct button hitTest (swizzle used to SIGSEGV here).
            XCTAssertNotNil(button.hitTest(centerInButton, with: nil))

            // Simulate pointer click → same path as touchUpInside → onSelect.
            button.sendActions(for: .touchUpInside)
        }

        XCTAssertEqual(
            chosen,
            [0, 1, 2],
            "onSelect must fire for each tab index under real button taps"
        )
    }
}
