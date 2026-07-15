import CoreGraphics
import Foundation
import UIKit

/// Pure layout / chrome metrics for large Mac windows vs phone.
/// Unit-tested without UIKit where possible.
enum ResponsiveMetrics {
    /// Whether main shell chrome (tabs + titlebar actions) should be visible.
    /// Expanded watch panel owns the surface — hide shell chrome.
    static func shellChromeVisible(playerExpanded: Bool) -> Bool {
        !playerExpanded
    }

    /// Whether the **system** `UITabBar` should be hidden.
    /// - Mac: always hidden (custom top tabs own chrome).
    /// - iOS: hidden only while shell chrome is hidden (expanded player).
    ///   Must not force `false` after theme/layout reconfigure — that would
    ///   re-show the tab bar under an expanded watch panel.
    static func systemTabBarHidden(
        isMac: Bool,
        shellChromeHidden: Bool
    ) -> Bool {
        if isMac { return true }
        return shellChromeHidden
    }

    /// Extra top inset for Mac **root** feeds under the title-bar tab pill.
    /// Tabs overlay the window title band; root nav bars are hidden on Mac,
    /// so **no multi-dozen-pt extra gap** is reserved under the pill.
    static func macRootFeedTopExtraInset() -> CGFloat {
        0
    }

    /// Leading clearance when a control shares the **title-bar row** with
    /// traffic lights (right of red/yellow/green).
    static func macTrafficLightLeadingInset() -> CGFloat {
        100
    }

    /// Leading inset when the watch close control sits **below** traffic lights.
    static func macWatchCloseLeadingInset() -> CGFloat {
        16
    }

    /// Top offset for Mac floating watch close — below the traffic-light row
    /// (~28–36pt titlebar), not beside the green button.
    static func macWatchCloseTopInset() -> CGFloat {
        44
    }

    /// Shared control height for Mac search chrome (back + field must match).
    static func macSearchControlHeight() -> CGFloat {
        40
    }

    /// Mac search field fill — theme-aware, opaque enough for readable text
    /// (glass-only fill made typed text disappear on dark Mac chrome).
    static func macSearchFieldFill(isDark: Bool) -> UIColor {
        if isDark {
            return UIColor(white: 0.22, alpha: 1)
        }
        return UIColor(white: 0.94, alpha: 1)
    }

    /// Typed text / caret — high contrast on `macSearchFieldFill`.
    static func macSearchFieldText(isDark: Bool) -> UIColor {
        if isDark {
            return .white
        }
        return UIColor(white: 0.08, alpha: 1)
    }

    /// Mac search placeholder / leading icon tint.
    static func macSearchFieldSecondary(isDark: Bool) -> UIColor {
        if isDark {
            return UIColor(white: 0.72, alpha: 1)
        }
        return UIColor(white: 0.42, alpha: 1)
    }

    /// Mac circular back control fill.
    static func macSearchBackFill(isDark: Bool) -> UIColor {
        if isDark {
            return UIColor.white.withAlphaComponent(0.16)
        }
        return UIColor.black.withAlphaComponent(0.08)
    }

    /// Height of the full-width pass-through strip hosting Mac top tabs.
    static func macTopTabStripHeight() -> CGFloat {
        48
    }

    /// Whether a hit inside the Mac top-tab control should take priority
    /// over full-bleed child content.
    static func macTopTabHitTakesPriority(
        pointInsideTabControl: Bool,
        shellChromeHidden: Bool
    ) -> Bool {
        pointInsideTabControl && !shellChromeHidden
    }

    /// Whether the system navigation bar should be hidden for a Mac stack.
    /// Root feed tabs: hidden (kills empty black band). Search: custom chrome.
    /// Pushed screens (channel, etc.): shown with chevron.
    /// **Modal sheets** (Settings Done): always show the bar.
    /// **Watch / player panel**: always show — back/minimize lives on the bar;
    ///   Watch is root of its own nav, so root-hide was removing the control.
    static func macNavigationBarHidden(
        isRoot: Bool,
        isSearchScreen: Bool,
        isPresentedModally: Bool = false,
        isWatchScreen: Bool = false
    ) -> Bool {
        if isPresentedModally || isWatchScreen {
            return false
        }
        return isRoot || isSearchScreen
    }

    /// Max video player height so metadata + comments keep usable space.
    /// Large Mac windows keep a **primary** video surface (not a tiny strip);
    /// residual comments/profile still remain reachable.
    /// - Parameters:
    ///   - containerWidth: available width for the player column
    ///   - containerHeight: full content height (safe area)
    ///   - minCommentsHeight: absolute floor for residual profile/comments
    static func maxPlayerHeight(
        containerWidth: CGFloat,
        containerHeight: CGFloat,
        minCommentsHeight: CGFloat = 280
    ) -> CGFloat {
        let widthBased = containerWidth * 9.0 / 16.0
        // Large windows: reserve less so the player can grow with the window.
        // Phone: keep classic near-16:9 (small residual floor).
        let reservedFraction: CGFloat
        if containerHeight >= 1_100 {
            reservedFraction = 0.28
        } else if containerHeight >= 800 {
            reservedFraction = 0.30
        } else {
            reservedFraction = 0.22
        }
        let commentsFloor: CGFloat
        if containerHeight >= 800 {
            commentsFloor = min(minCommentsHeight, 220)
        } else {
            commentsFloor = min(minCommentsHeight, 200)
        }
        let reserved = max(commentsFloor, containerHeight * reservedFraction)
        let heightCap = max(containerHeight - reserved, 200)
        // Soft absolute cap — raised so wide Mac columns are not crushed.
        let absoluteCap: CGFloat
        if containerWidth >= 1_600 {
            absoluteCap = 780
        } else if containerWidth >= 1_200 {
            absoluteCap = 700
        } else if containerWidth >= 800 {
            absoluteCap = 640
        } else {
            absoluteCap = 600
        }
        return min(widthBased, heightCap, absoluteCap)
    }

    /// Whether transport controls should treat the player as "playing"
    /// (fast pause path). Pure helper for unit tests + play/pause handler.
    static func isPlayerActivelyPlaying(rate: Float) -> Bool {
        rate > 0.01
    }

    /// Host window bounds usable for window-fill fullscreen (reject mid-transition zeros).
    static func isValidFullscreenHostBounds(_ size: CGSize) -> Bool {
        size.width >= 100 && size.height >= 100
    }

    /// Mac traffic-light green (system full-screen exit) while app player is
    /// window-hosted → leave app fullscreen so UI returns to inline player
    /// (avoids black-screen freeze when system chrome tears down).
    static func shouldExitAppFullscreenOnSystemFullScreenExit(
        isMac: Bool,
        isAppFullscreen: Bool
    ) -> Bool {
        isMac && isAppFullscreen
    }

    /// Significant window-area shrink while app-fullscreen (typical green-button
    /// exit from system full-screen) → restore inline player.
    static func shouldExitAppFullscreenOnHostShrink(
        previous: CGSize,
        current: CGSize,
        ratioThreshold: CGFloat = 0.85
    ) -> Bool {
        guard previous.width >= 100, previous.height >= 100,
              current.width >= 100, current.height >= 100
        else {
            return false
        }
        let prevArea = previous.width * previous.height
        let newArea = current.width * current.height
        guard prevArea > 1 else { return false }
        return (newArea / prevArea) < ratioThreshold
    }

    /// When system enters full-screen while app player already fills the window,
    /// only re-sync the frame (do not exit).
    static func shouldResyncAppFullscreenOnSystemFullScreenEnter(
        isMac: Bool,
        isAppFullscreen: Bool
    ) -> Bool {
        isMac && isAppFullscreen
    }

    /// Mac recover policy: only force-exit on confirmed host shrink.
    /// Mid-transition invalid bounds and enter-settling must **not** exit —
    /// that made the first fullscreen click appear to do nothing.
    static func shouldForceExitMacAppFullscreen(
        hostValid: Bool,
        isEnterSettling: Bool,
        hostDidShrink: Bool
    ) -> Bool {
        if isEnterSettling {
            return false
        }
        if !hostValid {
            return false
        }
        return hostDidShrink
    }

    /// Preferred 16:9 height then capped for residual comments space.
    static func playerHeight(
        containerWidth: CGFloat,
        containerHeight: CGFloat
    ) -> CGFloat {
        let natural = containerWidth * 9.0 / 16.0
        let maxH = maxPlayerHeight(
            containerWidth: containerWidth,
            containerHeight: containerHeight
        )
        return min(natural, maxH)
    }

    /// Use side-by-side watch layout when the window is wide enough
    /// (Mac landscape-or-large windows), not only when width > height.
    static func prefersWatchSidebar(
        containerWidth: CGFloat,
        containerHeight: CGFloat
    ) -> Bool {
        if containerWidth > containerHeight { return true }
        // Tall but very wide Mac windows still get a sidebar.
        return containerWidth >= 1_100
    }

    /// Icon point size scales with window width (phone → large Mac).
    /// Used for player gear/PiP glyphs and general chrome icons.
    static func iconPointSize(forWidth width: CGFloat) -> CGFloat {
        switch width {
        case ..<500: return 18
        case 500..<900: return 20
        case 900..<1_400: return 24
        default: return 28
        }
    }

    /// Watch action-bar glyph size (like / share / save / download).
    static func actionBarIconSize(forWidth width: CGFloat) -> CGFloat {
        switch width {
        case ..<500: return 22
        case 500..<900: return 24
        case 900..<1_400: return 28
        default: return 32
        }
    }

    /// Settings / gear glyph size (slightly larger than generic icon).
    static func settingsGlyphSize(forWidth width: CGFloat) -> CGFloat {
        max(26, iconPointSize(forWidth: width) + 4)
    }

    /// PiP glyph size tracks top control hit target.
    static func pipGlyphSize(forWidth width: CGFloat) -> CGFloat {
        max(26, topControlHitSize(forWidth: width) * 0.62)
    }

    /// Fullscreen corner glyph size.
    static func fullscreenGlyphSize(forWidth width: CGFloat) -> CGFloat {
        max(24, iconPointSize(forWidth: width))
    }

    /// Top player chrome control hit size (settings / PiP / CC / speed).
    static func topControlHitSize(forWidth width: CGFloat) -> CGFloat {
        switch width {
        case ..<500: return 36
        case 500..<900: return 40
        case 900..<1_400: return 44
        default: return 48
        }
    }

    /// Gap between top player chrome controls.
    static func topControlSpacing(forWidth width: CGFloat) -> CGFloat {
        switch width {
        case ..<500: return 6
        case 500..<900: return 10
        case 900..<1_400: return 14
        default: return 18
        }
    }

    /// Center transport control (play/pause) size.
    static func playControlSize(forWidth width: CGFloat) -> CGFloat {
        switch width {
        case ..<500: return 52
        case 500..<900: return 60
        case 900..<1_400: return 72
        default: return 84
        }
    }

    /// Skip forward/back control size.
    static func skipControlSize(forWidth width: CGFloat) -> CGFloat {
        playControlSize(forWidth: width) * 0.72
    }

    /// Titlebar / chrome action icon size on Mac.
    static func chromeActionIconSize(forWidth width: CGFloat) -> CGFloat {
        switch width {
        case ..<900: return 16
        case 900..<1_400: return 18
        default: return 20
        }
    }

    /// Body / chrome label font size on large surfaces.
    static func chromeLabelPointSize(forWidth width: CGFloat) -> CGFloat {
        switch width {
        case ..<500: return 13
        case 500..<900: return 14
        case 900..<1_400: return 15
        default: return 16
        }
    }

    /// Whether pointer hover affordances should be installed (Mac / trackpad).
    static func shouldInstallPointerHover(isMac: Bool) -> Bool {
        isMac
    }
}
