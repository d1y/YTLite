#import <TargetConditionals.h>
#import <UIKit/UIKit.h>

#if TARGET_OS_MACCATALYST

/// Ensure the bridged NSWindow has `fullScreenPrimary` collection behavior.
/// Call early (e.g. watch appear) so the first user toggle actually works.
/// Returns YES if an NSWindow was found and behavior was applied.
BOOL YTLitePrepareSystemFullScreen(UIWindow * _Nullable uiWindow);

/// Toggle macOS system full-screen for the app window that hosts `uiWindow`.
/// Returns YES if `toggleFullScreen:` was invoked.
/// Safe: never crashes on missing private keys (ObjC @try/@catch).
BOOL YTLiteToggleSystemFullScreen(UIWindow * _Nullable uiWindow);

/// YES if the bridged NSWindow reports the full-screen style mask.
BOOL YTLiteIsSystemFullScreen(UIWindow * _Nullable uiWindow);

#endif
