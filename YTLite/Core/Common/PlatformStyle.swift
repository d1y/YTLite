import UIKit

/// Platform layout / chrome helpers (Mac Catalyst vs iOS).
enum PlatformStyle {
    /// Running on macOS (Mac Catalyst, or iOS app on Mac).
    static var isMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        if #available(iOS 14.0, *) {
            if ProcessInfo.processInfo.isiOSAppOnMac {
                return true
            }
            if UIDevice.current.userInterfaceIdiom == .mac {
                return true
            }
        }
        if #available(iOS 13.0, *), ProcessInfo.processInfo.isMacCatalystApp {
            return true
        }
        return false
        #endif
    }

    /// macOS: action chrome lives in the window title bar trailing edge
    /// (not nav-bar right items, which sit too low / wrong glass layer).
    static var prefersMacTitlebarActions: Bool {
        isMac
    }
}
