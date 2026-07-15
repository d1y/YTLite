import UIKit

/// Display-level macOS full-screen helpers for Catalyst.
///
/// Implementation is in `MacAppKitFullscreen.m` (ObjC `@try/@catch` around
/// private KVC + `NSApp` fallback). Swift must **never** call
/// `value(forKey: "nsWindow")` — it aborts on macOS 26.
enum MacSystemWindowBridge {
    /// Style mask bit for full-screen (NSWindow.StyleMask.fullScreen).
    private static let fullScreenStyleMaskBit: UInt = 1 << 14

    static func styleMaskIndicatesFullScreen(_ mask: UInt) -> Bool {
        (mask & fullScreenStyleMaskBit) != 0
    }

    static func isSystemFullScreen(uiWindow: UIWindow?) -> Bool {
        guard PlatformStyle.isMac else {
            return false
        }
        #if targetEnvironment(macCatalyst)
        return YTLiteIsSystemFullScreen(uiWindow)
        #else
        return false
        #endif
    }

    /// Prime `fullScreenPrimary` so the first user toggle is not a no-op.
    @discardableResult
    static func prepareSystemFullScreen(uiWindow: UIWindow?) -> Bool {
        guard PlatformStyle.isMac else {
            return false
        }
        #if targetEnvironment(macCatalyst)
        return YTLitePrepareSystemFullScreen(uiWindow)
        #else
        return false
        #endif
    }

    @discardableResult
    static func toggleSystemFullScreen(uiWindow: UIWindow?) -> Bool {
        guard PlatformStyle.isMac else {
            return false
        }
        #if targetEnvironment(macCatalyst)
        return YTLiteToggleSystemFullScreen(uiWindow)
        #else
        return false
        #endif
    }

    @discardableResult
    static func enterSystemFullScreenIfNeeded(uiWindow: UIWindow?) -> Bool {
        guard PlatformStyle.isMac else {
            return false
        }
        if isSystemFullScreen(uiWindow: uiWindow) {
            return true
        }
        // Ensure behavior before toggle (first click reliability).
        _ = prepareSystemFullScreen(uiWindow: uiWindow)
        return toggleSystemFullScreen(uiWindow: uiWindow)
    }

    @discardableResult
    static func exitSystemFullScreenIfNeeded(uiWindow: UIWindow?) -> Bool {
        guard PlatformStyle.isMac else {
            return false
        }
        guard isSystemFullScreen(uiWindow: uiWindow) else {
            return false
        }
        return toggleSystemFullScreen(uiWindow: uiWindow)
    }
}
