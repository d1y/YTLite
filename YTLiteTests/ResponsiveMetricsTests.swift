import XCTest
@testable import YTLite

final class ResponsiveMetricsTests: XCTestCase {
    func testShellChromeHiddenWhenPlayerExpanded() {
        XCTAssertFalse(
            ResponsiveMetrics.shellChromeVisible(playerExpanded: true)
        )
        XCTAssertTrue(
            ResponsiveMetrics.shellChromeVisible(playerExpanded: false)
        )
    }

    /// Mac watch: shell must hide when player owns the surface.
    func testMacWatchHidesShellChromePolicy() {
        let playerExpanded = true
        let shellVisible = ResponsiveMetrics.shellChromeVisible(
            playerExpanded: playerExpanded
        )
        XCTAssertFalse(shellVisible)
        // System tab bar also hidden on Mac either way; Mac tabs are NSToolbar.
        XCTAssertTrue(
            ResponsiveMetrics.systemTabBarHidden(
                isMac: true,
                shellChromeHidden: !shellVisible
            )
        )
    }

    /// Mac root feed must not reserve a multi-dozen-pt empty band under tabs.
    func testMacRootFeedTopExtraInsetIsZero() {
        XCTAssertEqual(
            ResponsiveMetrics.macRootFeedTopExtraInset(),
            0,
            accuracy: 0.01
        )
    }

    /// Back control and search field share one height on Mac.
    func testMacSearchControlHeightIsUsableDesktopSize() {
        let h = ResponsiveMetrics.macSearchControlHeight()
        XCTAssertGreaterThanOrEqual(h, 36)
        XCTAssertLessThanOrEqual(h, 48)
        // Field uses the same metric (shipped SearchViewController).
        XCTAssertEqual(h, ResponsiveMetrics.macSearchControlHeight())
    }

    func testMacTopTabHitPriority() {
        XCTAssertTrue(
            ResponsiveMetrics.macTopTabHitTakesPriority(
                pointInsideTabControl: true,
                shellChromeHidden: false
            )
        )
        XCTAssertFalse(
            ResponsiveMetrics.macTopTabHitTakesPriority(
                pointInsideTabControl: false,
                shellChromeHidden: false
            )
        )
        XCTAssertFalse(
            ResponsiveMetrics.macTopTabHitTakesPriority(
                pointInsideTabControl: true,
                shellChromeHidden: true
            )
        )
    }

    func testMacNavigationBarHiddenForRootAndSearch() {
        XCTAssertTrue(
            ResponsiveMetrics.macNavigationBarHidden(
                isRoot: true,
                isSearchScreen: false
            )
        )
        XCTAssertTrue(
            ResponsiveMetrics.macNavigationBarHidden(
                isRoot: false,
                isSearchScreen: true
            )
        )
        XCTAssertFalse(
            ResponsiveMetrics.macNavigationBarHidden(
                isRoot: false,
                isSearchScreen: false
            )
        )
        // Modal Settings sheet must keep the nav bar (Done button).
        XCTAssertFalse(
            ResponsiveMetrics.macNavigationBarHidden(
                isRoot: true,
                isSearchScreen: false,
                isPresentedModally: true
            )
        )
        // Watch player panel is root of its nav — must still show bar (back).
        XCTAssertFalse(
            ResponsiveMetrics.macNavigationBarHidden(
                isRoot: true,
                isSearchScreen: false,
                isPresentedModally: false,
                isWatchScreen: true
            )
        )
    }

    func testFullScreenStyleMaskBit() {
        let fullScreenBit: UInt = 1 << 14
        XCTAssertTrue(
            MacSystemWindowBridge.styleMaskIndicatesFullScreen(fullScreenBit)
        )
        XCTAssertTrue(
            MacSystemWindowBridge.styleMaskIndicatesFullScreen(
                fullScreenBit | 15
            )
        )
        XCTAssertFalse(
            MacSystemWindowBridge.styleMaskIndicatesFullScreen(15)
        )
    }

    func testMacSearchFieldTextContrastsWithFill() {
        // Dark: white text on elevated gray fill (not clear-on-black).
        let darkText = ResponsiveMetrics.macSearchFieldText(isDark: true)
        let darkFill = ResponsiveMetrics.macSearchFieldFill(isDark: true)
        XCTAssertNotEqual(darkText, darkFill)
        // Light: near-black text on light fill.
        let lightText = ResponsiveMetrics.macSearchFieldText(isDark: false)
        let lightFill = ResponsiveMetrics.macSearchFieldFill(isDark: false)
        XCTAssertNotEqual(lightText, lightFill)
    }

    /// iOS must keep the system tab bar hidden while the expanded player
    /// owns the surface — even after theme/layout reconfigure that used to
    /// force `tabBar.isHidden = false`.
    func testSystemTabBarHiddenHonorsShellOnIOS() {
        // Feed shell visible → tab bar shown on iOS.
        XCTAssertFalse(
            ResponsiveMetrics.systemTabBarHidden(
                isMac: false,
                shellChromeHidden: false
            )
        )
        // Expanded player → shell hidden → tab bar must stay hidden on iOS.
        XCTAssertTrue(
            ResponsiveMetrics.systemTabBarHidden(
                isMac: false,
                shellChromeHidden: true
            )
        )
        // Mac always hides the system tab bar (custom top tabs).
        XCTAssertTrue(
            ResponsiveMetrics.systemTabBarHidden(
                isMac: true,
                shellChromeHidden: false
            )
        )
        XCTAssertTrue(
            ResponsiveMetrics.systemTabBarHidden(
                isMac: true,
                shellChromeHidden: true
            )
        )
    }

    /// End-to-end decision chain used by MainTabBarController:
    /// player expanded → shellChromeVisible false → system tab hidden on iOS.
    func testIOSTabBarHiddenChainMatchesExpandedPlayer() {
        let expanded = true
        let shellVisible = ResponsiveMetrics.shellChromeVisible(
            playerExpanded: expanded
        )
        let tabHidden = ResponsiveMetrics.systemTabBarHidden(
            isMac: false,
            shellChromeHidden: !shellVisible
        )
        XCTAssertFalse(shellVisible)
        XCTAssertTrue(tabHidden)

        let collapsed = false
        let shellVisible2 = ResponsiveMetrics.shellChromeVisible(
            playerExpanded: collapsed
        )
        let tabHidden2 = ResponsiveMetrics.systemTabBarHidden(
            isMac: false,
            shellChromeHidden: !shellVisible2
        )
        XCTAssertTrue(shellVisible2)
        XCTAssertFalse(tabHidden2)
    }

    func testPlayerHeightLeavesRoomForComments() {
        // Ultra-wide window: natural 16:9 would be huge — must cap.
        let width: CGFloat = 1600
        let height: CGFloat = 1000
        let playerH = ResponsiveMetrics.playerHeight(
            containerWidth: width,
            containerHeight: height
        )
        let maxH = ResponsiveMetrics.maxPlayerHeight(
            containerWidth: width,
            containerHeight: height
        )
        XCTAssertLessThanOrEqual(playerH, maxH)
        // Residual for comments/profile must stay usable.
        let residual = height - playerH
        XCTAssertGreaterThanOrEqual(residual, 220)
        XCTAssertGreaterThanOrEqual(residual, height * 0.25)
        // Must be smaller than unconstrained 16:9.
        XCTAssertLessThan(playerH, width * 9.0 / 16.0)
        // Large Mac player must not be crushed to the old ~480 strip.
        XCTAssertGreaterThanOrEqual(playerH, 560)
        XCTAssertLessThanOrEqual(playerH, 780)
    }

    func testVeryTallWindowStillReservesComments() {
        let width: CGFloat = 1400
        let height: CGFloat = 1200
        let playerH = ResponsiveMetrics.playerHeight(
            containerWidth: width,
            containerHeight: height
        )
        let residual = height - playerH
        // Keep residual comments space while allowing a large player.
        XCTAssertGreaterThanOrEqual(residual, height * 0.25)
        XCTAssertGreaterThanOrEqual(playerH, 560)
        XCTAssertLessThanOrEqual(playerH, 700)
    }

    func testMacTrafficLightLeadingInsetClearsCluster() {
        let inset = ResponsiveMetrics.macTrafficLightLeadingInset()
        // Traffic lights ~70–78pt; 100 leaves room for a 40pt circular control.
        XCTAssertGreaterThanOrEqual(inset, 96)
        XCTAssertLessThanOrEqual(inset, 120)
    }

    func testPlayerActivelyPlayingHelper() {
        XCTAssertTrue(
            ResponsiveMetrics.isPlayerActivelyPlaying(rate: 1.0)
        )
        XCTAssertTrue(
            ResponsiveMetrics.isPlayerActivelyPlaying(rate: 1.25)
        )
        XCTAssertFalse(
            ResponsiveMetrics.isPlayerActivelyPlaying(rate: 0)
        )
        XCTAssertFalse(
            ResponsiveMetrics.isPlayerActivelyPlaying(rate: 0.005)
        )
    }

    func testMacSearchThemeColorsDifferLightAndDark() {
        let darkFill = ResponsiveMetrics.macSearchFieldFill(isDark: true)
        let lightFill = ResponsiveMetrics.macSearchFieldFill(isDark: false)
        XCTAssertNotEqual(darkFill, lightFill)
        let darkBack = ResponsiveMetrics.macSearchBackFill(isDark: true)
        let lightBack = ResponsiveMetrics.macSearchBackFill(isDark: false)
        XCTAssertNotEqual(darkBack, lightBack)
        let darkSec = ResponsiveMetrics.macSearchFieldSecondary(isDark: true)
        let lightSec = ResponsiveMetrics.macSearchFieldSecondary(isDark: false)
        XCTAssertNotEqual(darkSec, lightSec)
    }

    func testValidFullscreenHostBoundsRejectsTiny() {
        XCTAssertFalse(
            ResponsiveMetrics.isValidFullscreenHostBounds(.zero)
        )
        XCTAssertFalse(
            ResponsiveMetrics.isValidFullscreenHostBounds(CGSize(width: 50, height: 800))
        )
        XCTAssertTrue(
            ResponsiveMetrics.isValidFullscreenHostBounds(CGSize(width: 800, height: 600))
        )
    }

    func testMacSystemFullScreenExitExitsAppFullscreen() {
        XCTAssertTrue(
            ResponsiveMetrics.shouldExitAppFullscreenOnSystemFullScreenExit(
                isMac: true,
                isAppFullscreen: true
            )
        )
        XCTAssertFalse(
            ResponsiveMetrics.shouldExitAppFullscreenOnSystemFullScreenExit(
                isMac: true,
                isAppFullscreen: false
            )
        )
        XCTAssertFalse(
            ResponsiveMetrics.shouldExitAppFullscreenOnSystemFullScreenExit(
                isMac: false,
                isAppFullscreen: true
            )
        )
    }

    func testMacSystemFullScreenEnterResyncsOnlyWhenAppFS() {
        XCTAssertTrue(
            ResponsiveMetrics.shouldResyncAppFullscreenOnSystemFullScreenEnter(
                isMac: true,
                isAppFullscreen: true
            )
        )
        XCTAssertFalse(
            ResponsiveMetrics.shouldResyncAppFullscreenOnSystemFullScreenEnter(
                isMac: true,
                isAppFullscreen: false
            )
        )
    }

    func testHostShrinkDetectsGreenButtonExit() {
        let full = CGSize(width: 1_920, height: 1_080)
        let windowed = CGSize(width: 1_200, height: 800)
        XCTAssertTrue(
            ResponsiveMetrics.shouldExitAppFullscreenOnHostShrink(
                previous: full,
                current: windowed
            )
        )
        // Tiny jitter while still full-screen should not exit.
        XCTAssertFalse(
            ResponsiveMetrics.shouldExitAppFullscreenOnHostShrink(
                previous: full,
                current: CGSize(width: 1_900, height: 1_070)
            )
        )
    }

    /// First fullscreen click: mid-enter 0×0 / settling must not force-exit.
    func testMacRecoverDoesNotForceExitDuringEnter() {
        XCTAssertFalse(
            ResponsiveMetrics.shouldForceExitMacAppFullscreen(
                hostValid: false,
                isEnterSettling: false,
                hostDidShrink: false
            ),
            "Invalid host mid-transition → wait, do not exit"
        )
        XCTAssertFalse(
            ResponsiveMetrics.shouldForceExitMacAppFullscreen(
                hostValid: false,
                isEnterSettling: true,
                hostDidShrink: true
            ),
            "Enter settling blocks exit even if shrink heuristic fires"
        )
        XCTAssertFalse(
            ResponsiveMetrics.shouldForceExitMacAppFullscreen(
                hostValid: true,
                isEnterSettling: true,
                hostDidShrink: true
            )
        )
        XCTAssertTrue(
            ResponsiveMetrics.shouldForceExitMacAppFullscreen(
                hostValid: true,
                isEnterSettling: false,
                hostDidShrink: true
            ),
            "Confirmed shrink after settle → exit app FS"
        )
    }

    func testPhonePlayerStillNearNaturalAspect() {
        let width: CGFloat = 390
        let height: CGFloat = 844
        let playerH = ResponsiveMetrics.playerHeight(
            containerWidth: width,
            containerHeight: height
        )
        let natural = width * 9.0 / 16.0
        // On phone, cap should not shrink below natural 16:9 much
        // (natural already leaves plenty of room).
        XCTAssertEqual(playerH, natural, accuracy: 1)
    }

    func testIconSizeGrowsWithWidth() {
        let phone = ResponsiveMetrics.iconPointSize(forWidth: 390)
        let large = ResponsiveMetrics.iconPointSize(forWidth: 1600)
        XCTAssertGreaterThanOrEqual(large, phone)
        XCTAssertGreaterThanOrEqual(large, 24)
    }

    func testSettingsGlyphUsesIconPointSizeRail() {
        // Production settingsGlyphSize is derived from iconPointSize.
        let phoneIcon = ResponsiveMetrics.iconPointSize(forWidth: 390)
        let largeIcon = ResponsiveMetrics.iconPointSize(forWidth: 1600)
        let phoneGear = ResponsiveMetrics.settingsGlyphSize(forWidth: 390)
        let largeGear = ResponsiveMetrics.settingsGlyphSize(forWidth: 1600)
        XCTAssertGreaterThanOrEqual(phoneGear, phoneIcon)
        XCTAssertGreaterThan(largeGear, phoneGear)
        XCTAssertEqual(
            largeGear,
            max(26, largeIcon + 4),
            accuracy: 0.1
        )
    }

    func testActionBarIconSizeGrowsWithWidth() {
        let phone = ResponsiveMetrics.actionBarIconSize(forWidth: 390)
        let large = ResponsiveMetrics.actionBarIconSize(forWidth: 1600)
        XCTAssertEqual(phone, 22, accuracy: 0.1)
        XCTAssertEqual(large, 32, accuracy: 0.1)
        XCTAssertGreaterThan(large, phone)
    }

    func testPlayerIconsPlayGlyphRendersAtRequestedSize() {
        // Shipped PlayerIcons must re-render bitmaps — not just stretch frames.
        let phone = PlayerIcons.play(size: 44)
        let large = PlayerIcons.play(size: 84)
        XCTAssertEqual(phone.size.width, 44, accuracy: 0.5)
        XCTAssertEqual(phone.size.height, 44, accuracy: 0.5)
        XCTAssertEqual(large.size.width, 84, accuracy: 0.5)
        XCTAssertEqual(large.size.height, 84, accuracy: 0.5)
    }

    /// Watch action-bar icons must cache rasters (layout thrash → 0x8BADF00D).
    func testActionBarIconCacheReturnsSameInstance() {
        PlayerIcons.clearActionBarIconCache()
        let a = PlayerIcons.actionBarIcon(named: "icon_thumb_up", size: 22)
        let b = PlayerIcons.actionBarIcon(named: "icon_thumb_up", size: 22)
        guard let a, let b else {
            XCTFail("icon_thumb_up asset missing")
            return
        }
        XCTAssertTrue(a === b, "Same size must hit cache (identity)")
        XCTAssertEqual(a.size.width, 22, accuracy: 0.5)
        let c = PlayerIcons.actionBarIcon(named: "icon_thumb_up", size: 32)
        XCTAssertNotNil(c)
        XCTAssertFalse(a === c, "Different size must be a new raster")
    }

    /// Player transport icons (crash stack: playerIcon / reapplyScaledGlyphs).
    func testPlayerTransportIconCacheReturnsSameInstance() {
        PlayerIcons.clearActionBarIconCache()
        let a = PlayerIcons.rewind10(size: 36)
        let b = PlayerIcons.rewind10(size: 36)
        XCTAssertTrue(a === b, "playerIcon must cache by name+size")
        let playA = PlayerIcons.play(size: 44)
        let playB = PlayerIcons.play(size: 44)
        XCTAssertTrue(playA === playB, "vector play glyph must cache")
    }

    func testPlayerIconsSettingsGlyphRendersAtRequestedSize() {
        let phone = PlayerIcons.settings(size: 26)
        let large = PlayerIcons.settings(
            size: ResponsiveMetrics.settingsGlyphSize(forWidth: 1600)
        )
        XCTAssertEqual(phone.size.width, 26, accuracy: 0.5)
        XCTAssertGreaterThan(large.size.width, phone.size.width)
        XCTAssertEqual(
            large.size.width,
            ResponsiveMetrics.settingsGlyphSize(forWidth: 1600),
            accuracy: 0.5
        )
    }

    func testPlayerIconsSkipGlyphTracksSkipControlSize() {
        let phoneSkip = ResponsiveMetrics.skipControlSize(forWidth: 390)
        let largeSkip = ResponsiveMetrics.skipControlSize(forWidth: 1600)
        let phoneImg = PlayerIcons.rewind10(size: phoneSkip)
        let largeImg = PlayerIcons.rewind10(size: largeSkip)
        XCTAssertEqual(phoneImg.size.width, phoneSkip, accuracy: 0.5)
        XCTAssertEqual(largeImg.size.width, largeSkip, accuracy: 0.5)
        XCTAssertGreaterThan(largeImg.size.width, phoneImg.size.width)
    }

    func testPipAndFullscreenGlyphHelpersScale() {
        let phonePip = ResponsiveMetrics.pipGlyphSize(forWidth: 390)
        let largePip = ResponsiveMetrics.pipGlyphSize(forWidth: 1600)
        XCTAssertGreaterThan(largePip, phonePip)
        let phoneFS = ResponsiveMetrics.fullscreenGlyphSize(forWidth: 390)
        let largeFS = ResponsiveMetrics.fullscreenGlyphSize(forWidth: 1600)
        XCTAssertGreaterThanOrEqual(largeFS, phoneFS)
        let pipImg = PlayerIcons.pip(size: largePip)
        // SF Symbol size may differ slightly from request; still larger than default.
        XCTAssertGreaterThan(pipImg.size.width, 10)
    }

    func testTopControlHitSizeGrowsWithWidth() {
        let phone = ResponsiveMetrics.topControlHitSize(forWidth: 390)
        let large = ResponsiveMetrics.topControlHitSize(forWidth: 1600)
        XCTAssertGreaterThan(large, phone)
        XCTAssertEqual(phone, 36, accuracy: 0.1)
        XCTAssertEqual(large, 48, accuracy: 0.1)
    }

    func testTopControlSpacingGrowsWithWidth() {
        let phone = ResponsiveMetrics.topControlSpacing(forWidth: 390)
        let large = ResponsiveMetrics.topControlSpacing(forWidth: 1600)
        XCTAssertGreaterThan(large, phone)
    }

    func testPlayControlSizeGrowsWithWidth() {
        let phone = ResponsiveMetrics.playControlSize(forWidth: 390)
        let large = ResponsiveMetrics.playControlSize(forWidth: 1600)
        XCTAssertGreaterThan(large, phone)
        XCTAssertEqual(phone, 52, accuracy: 0.1)
        XCTAssertEqual(large, 84, accuracy: 0.1)
    }

    func testWatchSidebarPreferredOnWideWindow() {
        XCTAssertTrue(
            ResponsiveMetrics.prefersWatchSidebar(
                containerWidth: 1400,
                containerHeight: 900
            )
        )
        // Tall phone portrait — no sidebar.
        XCTAssertFalse(
            ResponsiveMetrics.prefersWatchSidebar(
                containerWidth: 390,
                containerHeight: 844
            )
        )
        // Very wide but taller-than-wide Mac window.
        XCTAssertTrue(
            ResponsiveMetrics.prefersWatchSidebar(
                containerWidth: 1200,
                containerHeight: 1300
            )
        )
    }

    func testPointerHoverOnlyOnMac() {
        XCTAssertTrue(
            ResponsiveMetrics.shouldInstallPointerHover(isMac: true)
        )
        XCTAssertFalse(
            ResponsiveMetrics.shouldInstallPointerHover(isMac: false)
        )
    }
}
