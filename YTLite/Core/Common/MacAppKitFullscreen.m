#import "MacAppKitFullscreen.h"

#if TARGET_OS_MACCATALYST

#import <objc/message.h>
#import <objc/runtime.h>

/// Runtime-only AppKit access — typed NSWindow/NSApp are unavailable on
/// Mac Catalyst headers (macOS 26 SDK). objc_msgSend + @try avoids both
/// compile errors and NSUndefinedKeyException aborts.

static id YTLiteMsg0(id target, const char *selName) {
    if (target == nil) {
        return nil;
    }
    SEL sel = sel_registerName(selName);
    if (![target respondsToSelector:sel]) {
        return nil;
    }
    return ((id (*)(id, SEL))objc_msgSend)(target, sel);
}

static void YTLiteMsg1(id target, const char *selName, id arg) {
    if (target == nil) {
        return;
    }
    SEL sel = sel_registerName(selName);
    if (![target respondsToSelector:sel]) {
        return;
    }
    ((void (*)(id, SEL, id))objc_msgSend)(target, sel, arg);
}

static unsigned long long YTLiteMsgULong(id target, const char *selName) {
    if (target == nil) {
        return 0;
    }
    SEL sel = sel_registerName(selName);
    if (![target respondsToSelector:sel]) {
        return 0;
    }
    return ((unsigned long long (*)(id, SEL))objc_msgSend)(target, sel);
}

static id YTLiteFindNSWindow(UIWindow *uiWindow) {
    if (uiWindow != nil) {
        @try {
            id candidate = [uiWindow valueForKey:@"nsWindow"];
            if (candidate != nil) {
                return candidate;
            }
        } @catch (__unused NSException *ex) {
            // undefined key — ignore
        }
    }

    Class appClass = NSClassFromString(@"NSApplication");
    if (appClass == Nil) {
        return nil;
    }
    id app = YTLiteMsg0((id)appClass, "sharedApplication");
    if (app == nil) {
        return nil;
    }
    id key = YTLiteMsg0(app, "keyWindow");
    if (key != nil) {
        return key;
    }
    id main = YTLiteMsg0(app, "mainWindow");
    if (main != nil) {
        return main;
    }
    id windows = YTLiteMsg0(app, "windows");
    if ([windows isKindOfClass:[NSArray class]] && [windows count] > 0) {
        return [windows firstObject];
    }
    return nil;
}

/// Apply fullScreenPrimary so toggleFullScreen: is allowed.
/// First user click often no-ops if this bit was never set before.
static BOOL YTLiteEnsureFullScreenPrimary(id window) {
    if (window == nil) {
        return NO;
    }
    SEL getBehavior = sel_registerName("collectionBehavior");
    SEL setBehavior = sel_registerName("setCollectionBehavior:");
    if (![window respondsToSelector:getBehavior] ||
        ![window respondsToSelector:setBehavior]) {
        return NO;
    }
    unsigned long long behavior =
        ((unsigned long long (*)(id, SEL))objc_msgSend)(window, getBehavior);
    // NSWindowCollectionBehaviorFullScreenPrimary = 1 << 7
    const unsigned long long fullScreenPrimary = (1ULL << 7);
    if ((behavior & fullScreenPrimary) == 0) {
        behavior |= fullScreenPrimary;
        ((void (*)(id, SEL, unsigned long long))objc_msgSend)(
            window, setBehavior, behavior
        );
    }
    return YES;
}

BOOL YTLitePrepareSystemFullScreen(UIWindow *uiWindow) {
    id window = YTLiteFindNSWindow(uiWindow);
    if (window == nil) {
        return NO;
    }
    return YTLiteEnsureFullScreenPrimary(window);
}

BOOL YTLiteToggleSystemFullScreen(UIWindow *uiWindow) {
    id window = YTLiteFindNSWindow(uiWindow);
    if (window == nil) {
        return NO;
    }
    // Must be set before toggle; first-ever toggle without this is a no-op
    // on many macOS versions (second click then "suddenly works").
    (void)YTLiteEnsureFullScreenPrimary(window);
    if (![window respondsToSelector:sel_registerName("toggleFullScreen:")]) {
        return NO;
    }
    YTLiteMsg1(window, "toggleFullScreen:", nil);
    return YES;
}

BOOL YTLiteIsSystemFullScreen(UIWindow *uiWindow) {
    id window = YTLiteFindNSWindow(uiWindow);
    if (window == nil) {
        return NO;
    }
    // NSWindowStyleMaskFullScreen = 1 << 14
    unsigned long long mask = YTLiteMsgULong(window, "styleMask");
    return (mask & (1ULL << 14)) != 0;
}

#endif
