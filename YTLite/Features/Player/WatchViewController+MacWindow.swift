import UIKit

// MARK: - Mac window geometry recovery (no AppKit on Catalyst)

extension WatchViewController {
    /// True while app player is window-hosted (app fullscreen).
    var isAppWindowFillFullscreen: Bool {
        fullscreenSnapshot != nil && videoPlayerView?.isFullscreen == true
    }

    /// True during the system full-screen enter animation grace window.
    var isMacFSSettling: Bool {
        guard let until = macFSSettleUntil else {
            return false
        }
        if Date() < until {
            return true
        }
        macFSSettleUntil = nil
        return false
    }

    /// Mark enter-settling so mid-transition recover does not force-exit.
    func beginMacFSSettle(seconds: TimeInterval = 1.0) {
        macFSSettleUntil = Date().addingTimeInterval(seconds)
    }

    func endMacFSSettle() {
        macFSSettleUntil = nil
    }

    /// UIKit-only observers: Catalyst cannot use `NSWindow` full-screen notes.
    func installMacWindowObserversIfNeeded() {
        guard PlatformStyle.isMac, !didInstallMacWindowObservers else {
            return
        }
        didInstallMacWindowObservers = true
        registerMacWindowGeometryObservers()
        // Prime fullScreenPrimary so the first player FS click is not a no-op.
        DispatchQueue.main.async { [weak self] in
            self?.primeMacSystemFullScreenCapability()
        }
    }

    private func registerMacWindowGeometryObservers() {
        let nc = NotificationCenter.default
        let sel = #selector(macSceneOrWindowGeometryMayHaveChanged(_:))
        nc.addObserver(
            self,
            selector: sel,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        if #available(iOS 13.0, *) {
            nc.addObserver(
                self,
                selector: sel,
                name: UIScene.didActivateNotification,
                object: nil
            )
            nc.addObserver(
                self,
                selector: sel,
                name: UIScene.willDeactivateNotification,
                object: nil
            )
        }
    }

    /// Set NSWindowCollectionBehaviorFullScreenPrimary before any user toggle.
    func primeMacSystemFullScreenCapability() {
        guard PlatformStyle.isMac else {
            return
        }
        _ = MacSystemWindowBridge.prepareSystemFullScreen(uiWindow: view.window)
    }

    @objc
    private func macSceneOrWindowGeometryMayHaveChanged(_ note: Notification) {
        guard PlatformStyle.isMac, isAppWindowFillFullscreen else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.recoverMacFullscreenIfNeeded()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.recoverMacFullscreenIfNeeded()
        }
    }

    /// Re-sync or exit app FS after Mac window geometry changes.
    /// Mid-transition 0×0 must not force-exit (that aborted the first FS click).
    func recoverMacFullscreenIfNeeded() {
        guard PlatformStyle.isMac else {
            return
        }
        guard let playerView = videoPlayerView else {
            return
        }
        guard isAppWindowFillFullscreen || playerView.isFullscreen else {
            lastMacFullscreenHostSize = .zero
            return
        }
        if isMacFSSettling {
            resyncMacFSWhileSettling()
            return
        }
        applyMacFSRecovery(playerView: playerView)
    }

    private func resyncMacFSWhileSettling() {
        guard let window = view.window,
              ResponsiveMetrics.isValidFullscreenHostBounds(window.bounds.size)
        else {
            return
        }
        syncFullscreenPlayerFrame(in: window)
        lastMacFullscreenHostSize = window.bounds.size
    }

    private func applyMacFSRecovery(playerView: VideoPlayerView) {
        guard let window = view.window else {
            forceExitFullscreen(playerView: playerView)
            lastMacFullscreenHostSize = .zero
            return
        }
        let hostSize = window.bounds.size
        guard ResponsiveMetrics.isValidFullscreenHostBounds(hostSize) else {
            return
        }
        if ResponsiveMetrics.shouldExitAppFullscreenOnHostShrink(
            previous: lastMacFullscreenHostSize,
            current: hostSize
        ) {
            forceExitFullscreen(playerView: playerView)
            lastMacFullscreenHostSize = .zero
            return
        }
        syncFullscreenPlayerFrame(in: window)
        lastMacFullscreenHostSize = hostSize
    }

    /// Called from `viewWillTransition` on Mac while app-fullscreen.
    func handleMacFullscreenSizeTransition(
        to size: CGSize,
        coordinator: UIViewControllerTransitionCoordinator
    ) {
        guard PlatformStyle.isMac, isAppWindowFillFullscreen else {
            return
        }
        let valid = ResponsiveMetrics.isValidFullscreenHostBounds(size)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            if valid {
                self?.syncFullscreenPlayerFrame()
            }
        }, completion: { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.recoverMacFullscreenIfNeeded()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.recoverMacFullscreenIfNeeded()
            }
        })
    }
}
