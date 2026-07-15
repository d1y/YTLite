import UIKit
import XCTest
@testable import YTLite

/// Proves the shipped Liquid Glass path is live — not dead helpers.
final class GlassChromeTests: XCTestCase {
    func testInstallBackdropUsesUIGlassEffectWhenAvailable() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 80))
        let backdrop = GlassChrome.installBackdrop(in: host, cornerRadius: 12)

        XCTAssertTrue(host.subviews.contains(backdrop))
        XCTAssertEqual(backdrop.tag, GlassChrome.backdropTag)

        if #available(iOS 26.0, macCatalyst 26.0, *) {
            guard let effectView = backdrop as? UIVisualEffectView else {
                XCTFail("Expected UIVisualEffectView backdrop on iOS 26+")
                return
            }
            XCTAssertTrue(
                effectView.effect is UIGlassEffect,
                "installBackdrop must attach UIGlassEffect, not blur/solid only"
            )
            XCTAssertTrue(GlassChrome.hostsGlassEffect(host))
            // Factory itself returns the real type used by installBackdrop.
            let effect = GlassChrome.makeGlassEffect()
            XCTAssertNotNil(effect)
            XCTAssertTrue(effect.isInteractive)
            XCTAssertTrue(
                type(of: effect) == UIGlassEffect.self
                    || effect is UIGlassEffect
            )
        } else {
            XCTAssertFalse(backdrop is UIVisualEffectView)
            XCTAssertFalse(GlassChrome.isGlassAvailable)
        }
    }

    func testStyleFloatingCardInstallsGlassOnModernOS() {
        let card = UIView(frame: CGRect(x: 0, y: 0, width: 160, height: 100))
        let result = GlassChrome.styleFloatingCard(card)

        if #available(iOS 26.0, macCatalyst 26.0, *) {
            XCTAssertTrue(
                GlassChrome.hostsGlassEffect(card),
                "styleFloatingCard must install UIGlassEffect, not only alpha fill"
            )
            XCTAssertEqual(card.backgroundColor, UIColor.clear)
            XCTAssertTrue(result is UIVisualEffectView)
            if let effectView = result as? UIVisualEffectView {
                XCTAssertTrue(effectView.effect is UIGlassEffect)
            }
        } else {
            XCTAssertNotNil(card.backgroundColor)
            XCTAssertFalse(GlassChrome.hostsGlassEffect(card))
        }
    }

    func testMiniPlayerBarHostsLiquidGlassOnModernOS() {
        let bar = MiniPlayerBar(frame: CGRect(x: 0, y: 0, width: 200, height: 140))
        // Force layout so subviews exist.
        bar.layoutIfNeeded()
        bar.applyTheme()

        XCTAssertNotNil(bar.cardBackdrop)
        XCTAssertNotNil(bar.infoBackdrop)

        if #available(iOS 26.0, macCatalyst 26.0, *) {
            XCTAssertTrue(
                bar.hostsLiquidGlass,
                "MiniPlayerBar must wire UIGlassEffect via installBackdrop/styleFloatingCard"
            )
            XCTAssertTrue(GlassChrome.hostsGlassEffect(bar))
            // Info strip also gets glass, not a solid alpha surface.
            if let infoBackdrop = bar.infoBackdrop as? UIVisualEffectView {
                XCTAssertTrue(infoBackdrop.effect is UIGlassEffect)
            } else {
                XCTFail("infoBackdrop must be UIVisualEffectView with UIGlassEffect")
            }
        }
    }

    func testInstallBackdropIsIdempotent() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        let first = GlassChrome.installBackdrop(in: host)
        let second = GlassChrome.installBackdrop(in: host)
        let tagged = host.subviews.filter { $0.tag == GlassChrome.backdropTag }
        XCTAssertEqual(tagged.count, 1, "Re-install must replace prior backdrop")
        XCTAssertTrue(host.subviews.contains(second))
        XCTAssertFalse(host.subviews.contains(first) && first !== second)
    }
}
