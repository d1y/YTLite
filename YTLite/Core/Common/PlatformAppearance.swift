import UIKit

/// Mac Catalyst cannot set `NSApp.appearance` (unavailable). Appearance for
/// title-bar toolbars is driven by:
/// 1. `UIWindow.overrideUserInterfaceStyle` (ThemeManager)
/// 2. Rebuilding toolbar items with theme-correct **template** symbols
///    (`MacActionChromeBar.applyTheme`)
enum PlatformAppearance {
    static func applyAppKit(for theme: ThemeManager = .shared) {
        // Intentionally empty on Catalyst — see file comment.
        // Kept as a single call site so a future public API can plug in here.
        _ = theme.isDark
    }
}
