import UIKit

// MARK: - VideoPlayerViewDelegate

extension WatchViewController: VideoPlayerViewDelegate {
    func videoPlayerViewDidTapSettings(
        _ playerView: VideoPlayerView
    ) {
        let alert = UIAlertController(
            title: "Playback settings",
            message: nil,
            preferredStyle: .actionSheet
        )
        alert.addAction(
            UIAlertAction(
                title: "Quality",
                style: .default
            ) { [weak self] _ in
                self?.showQualityPicker()
            }
        )
        alert.addAction(
            UIAlertAction(title: "Cancel", style: .cancel)
        )
        configurePopover(
            for: alert,
            sourceView: playerView
        )
        present(alert, animated: true)
    }

    func videoPlayerViewDidTapFullscreen(_ playerView: VideoPlayerView) {
        if playerView.isFullscreen {
            // Landscape path uses transform; window-fill path uses frame.
            if isLandscapeFullscreen {
                exitLandscapeFullscreen(playerView: playerView)
            } else {
                exitFullscreen(playerView: playerView)
            }
            return
        }
        // Mac Catalyst reports .pad or .mac — always use window-fill, never
        // the iPhone rotate-transform path (that freezes on system Cmd+Shift+F).
        if PlatformStyle.isMac
            || UIDevice.current.userInterfaceIdiom == .pad {
            enterFullscreen(playerView: playerView)
        } else {
            let orientation = UIDevice.current.orientation
            let landscape: UIDeviceOrientation = orientation.isLandscape
                ? orientation : .landscapeLeft
            enterLandscapeFullscreen(
                playerView: playerView,
                orientation: landscape
            )
        }
    }

    func enterFullscreen(playerView: VideoPlayerView) {
        guard let window = view.window else {
            return
        }
        // Already hosted on the window (e.g. re-entry after system FS).
        if playerView.superview === window, playerView.isFullscreen {
            syncFullscreenPlayerFrame(in: window)
            if PlatformStyle.isMac {
                requestMacSystemFullScreenIfNeeded(window: window)
            }
            return
        }
        let frameInWindow = playerView.convert(
            playerView.bounds, to: window
        )
        fullscreenSnapshot = (
            superview: playerView.superview ?? view,
            frame: playerView.frame
        )
        playerView.removeFromSuperview()
        playerView.transform = .identity
        playerView.translatesAutoresizingMaskIntoConstraints = true
        // Resize with the window — critical for macOS system full-screen.
        playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerView.frame = frameInWindow
        window.addSubview(playerView)
        playerView.isFullscreen = true
        isLandscapeFullscreen = false
        if PlatformStyle.isMac {
            lastMacFullscreenHostSize = window.bounds.size
            // Keep close reachable over window-fill player (on the window).
            pinMacCloseControl(to: window, useSafeAreaTop: false)
            updateMacCloseControlAppearance()
        }
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            playerView.frame = window.bounds
        } completion: { [weak self] _ in
            playerView.frame = window.bounds
            playerView.setNeedsLayout()
            playerView.layoutIfNeeded()
            guard let self else { return }
            if PlatformStyle.isMac {
                self.lastMacFullscreenHostSize = window.bounds.size
                // After window-fill, request **display-level** full-screen
                // (green traffic-light equivalent), not only UIWindow bounds.
                self.requestMacSystemFullScreenIfNeeded(window: window)
            }
        }
    }

    /// Mac: attempt display-level full-screen only when a safe bridge exists.
    /// Never KVC-probes private keys (crashed on macOS 26). Soft no-op is OK —
    /// window-fill fullscreen already covers the player surface.
    ///
    /// First-click reliability:
    /// 1. Prime `fullScreenPrimary` (first toggle without it is often a no-op).
    /// 2. Defer `toggleFullScreen:` one run-loop so behavior sticks.
    /// 3. Grace-window recover so mid-transition 0×0 does not force-exit.
    func requestMacSystemFullScreenIfNeeded(window: UIWindow) {
        guard PlatformStyle.isMac else {
            return
        }
        if MacSystemWindowBridge.isSystemFullScreen(uiWindow: window) {
            didRequestMacSystemFullScreen = true
            endMacFSSettle()
            return
        }
        // Prime before toggle; also primed on watch appear.
        _ = MacSystemWindowBridge.prepareSystemFullScreen(uiWindow: window)
        beginMacFSSettle(seconds: 1.0)
        // Same-turn prepare+toggle is flaky on first use — defer toggle.
        DispatchQueue.main.async { [weak self] in
            self?.performDeferredMacSystemFullScreen(fallback: window)
        }
    }

    private func performDeferredMacSystemFullScreen(fallback: UIWindow) {
        guard isAppWindowFillFullscreen else {
            return
        }
        let host = view.window ?? fallback
        let ok = MacSystemWindowBridge.enterSystemFullScreenIfNeeded(
            uiWindow: host
        )
        didRequestMacSystemFullScreen = ok
        if !ok {
            AppLog.player(
                "Mac system fullscreen unavailable — using window-fill only"
            )
            endMacFSSettle()
            return
        }
        // If still not system-FS after a beat, retry once (first-click path).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.retryMacSystemFullScreenIfNeeded(fallback: fallback)
        }
    }

    private func retryMacSystemFullScreenIfNeeded(fallback: UIWindow) {
        guard isAppWindowFillFullscreen else {
            return
        }
        let host = view.window ?? fallback
        if MacSystemWindowBridge.isSystemFullScreen(uiWindow: host) {
            didRequestMacSystemFullScreen = true
            syncFullscreenPlayerFrame(in: host)
            return
        }
        let retried = MacSystemWindowBridge.enterSystemFullScreenIfNeeded(
            uiWindow: host
        )
        didRequestMacSystemFullScreen = retried
        if retried {
            beginMacFSSettle(seconds: 0.8)
        } else {
            endMacFSSettle()
        }
    }

    /// Mac: leave system full-screen when we entered it for app fullscreen.
    func exitMacSystemFullScreenIfNeeded() {
        guard PlatformStyle.isMac, didRequestMacSystemFullScreen else {
            return
        }
        endMacFSSettle()
        _ = MacSystemWindowBridge.exitSystemFullScreenIfNeeded(
            uiWindow: view.window
        )
        didRequestMacSystemFullScreen = false
    }

    /// Keep window-hosted player in sync after system full-screen toggles.
    func syncFullscreenPlayerFrame(in window: UIWindow? = nil) {
        guard fullscreenSnapshot != nil,
              let playerView = videoPlayerView,
              playerView.isFullscreen
        else {
            return
        }
        let host = window ?? view.window
        guard let host else {
            forceExitFullscreen(playerView: playerView)
            return
        }
        let bounds = host.bounds
        // Mid system-FS transition often reports 0×0 — don't paint black forever.
        guard ResponsiveMetrics.isValidFullscreenHostBounds(bounds.size) else {
            return
        }
        playerView.isHidden = false
        playerView.alpha = 1
        playerView.backgroundColor = .black
        playerView.layer.removeAllAnimations()
        playerView.transform = .identity
        playerView.translatesAutoresizingMaskIntoConstraints = true
        playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Re-host if system chrome detached the player.
        if playerView.superview !== host {
            playerView.removeFromSuperview()
            host.addSubview(playerView)
        }
        playerView.frame = bounds
        host.bringSubviewToFront(playerView)
        playerView.setNeedsLayout()
        playerView.layoutIfNeeded()
    }

    func exitFullscreen(playerView: VideoPlayerView) {
        // Leave display-level full-screen first so restore layout uses
        // the normal windowed geometry.
        exitMacSystemFullScreenIfNeeded()
        guard let window = view.window,
              let snap = fullscreenSnapshot,
              snap.superview.window != nil
        else {
            // Recover from a broken fullscreen state (black screen / stuck).
            forceExitFullscreen(playerView: playerView)
            return
        }
        playerView.autoresizingMask = []
        playerView.layer.removeAllAnimations()
        let target = snap.superview.convert(snap.frame, to: window)
        // Invalid target after system FS teardown → hard restore.
        if !ResponsiveMetrics.isValidFullscreenHostBounds(target.size)
            || target.width < 1 || target.height < 1 {
            forceExitFullscreen(playerView: playerView)
            return
        }
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                playerView.transform = .identity
                playerView.frame = target
            }, completion: { [weak self] _ in
                self?.restoreFromFullscreen(playerView: playerView, snapshot: snap)
            }
        )
    }

    /// Last-resort recover when snapshot is lost after system FS / black screen.
    /// Always re-parents into `playerContainer` so the watch page is usable again.
    func forceExitFullscreen(playerView: VideoPlayerView) {
        exitMacSystemFullScreenIfNeeded()
        playerView.layer.removeAllAnimations()
        playerView.transform = .identity
        playerView.autoresizingMask = []
        playerView.isHidden = false
        playerView.alpha = 1
        playerView.isFullscreen = false
        isLandscapeFullscreen = false
        fullscreenSnapshot = nil
        lastMacFullscreenHostSize = .zero
        endMacFSSettle()

        playerView.removeFromSuperview()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        // Drop any leftover constraints from a previous host.
        playerContainer.addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: playerContainer.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: playerContainer.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: playerContainer.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: playerContainer.bottomAnchor)
        ])
        restoreMacCloseControlToWatchView()

        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        // Layout after hierarchy settles (system FS chrome may still be animating).
        DispatchQueue.main.async { [weak self] in
            self?.updateLayoutForSize()
            self?.view.setNeedsLayout()
            self?.view.layoutIfNeeded()
        }
    }

    /// Re-host floating Mac close after leaving window-fill fullscreen.
    func restoreMacCloseControlToWatchView() {
        guard PlatformStyle.isMac else { return }
        pinMacCloseControl(to: view, useSafeAreaTop: true)
        updateMacCloseControlAppearance()
    }

    func restoreFromFullscreen(
        playerView: VideoPlayerView,
        snapshot: (superview: UIView, frame: CGRect)
    ) {
        // Snapshot host may have been torn down by system full-screen chrome.
        let host = snapshot.superview
        if host.window == nil || host.bounds.width < 1 {
            forceExitFullscreen(playerView: playerView)
            return
        }
        playerView.removeFromSuperview()
        playerView.transform = .identity
        playerView.bounds = CGRect(origin: .zero, size: snapshot.frame.size)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.autoresizingMask = []
        host.addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: host.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        playerView.isFullscreen = false
        isLandscapeFullscreen = false
        fullscreenSnapshot = nil
        didRequestMacSystemFullScreen = false
        endMacFSSettle()
        restoreMacCloseControlToWatchView()
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        updateLayoutForSize()
    }

    func configurePopover(
        for alert: UIAlertController,
        sourceView: UIView?
    ) {
        guard let pop = alert.popoverPresentationController,
              let source = sourceView else {
            return
        }
        pop.sourceView = source
        pop.sourceRect = CGRect(
            x: source.bounds.maxX - 50,
            y: 20,
            width: 1,
            height: 1
        )
    }
}

// MARK: - Status bar / home indicator

extension WatchViewController {
    static var hidesStatusBarInFullscreen: Bool {
        UserDefaults.standard.object(
            forKey: UserDefaultsKeys.Player.hideStatusBarInFullscreen
        ) as? Bool ?? true
    }

    /// Fullscreen via either path — iPhone transform-based landscape or the
    /// iPad window-fill (`enterFullscreen`).
    var isPlayerFullscreen: Bool {
        isLandscapeFullscreen || videoPlayerView?.isFullscreen == true
    }

    override var prefersStatusBarHidden: Bool {
        isPlayerFullscreen && Self.hidesStatusBarInFullscreen
    }

    /// Over fullscreen video the bar must be light regardless of theme —
    /// `.default` is black-on-black there (looks "hidden", except a charging
    /// battery icon).
    override var preferredStatusBarStyle: UIStatusBarStyle {
        isPlayerFullscreen ? .lightContent : ThemeManager.shared.statusBarStyle
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        isPlayerFullscreen
    }
}

// MARK: - iPhone landscape fullscreen (no UI rotation)
extension WatchViewController {
    func enterLandscapeFullscreen(
        playerView: VideoPlayerView,
        orientation: UIDeviceOrientation
    ) {
        guard let window = view.window else {
            return
        }
        let frameInWindow = playerView.convert(playerView.bounds, to: window)
        if fullscreenSnapshot == nil {
            fullscreenSnapshot = (
                superview: playerView.superview ?? view,
                frame: playerView.frame
            )
        }
        isLandscapeFullscreen = true
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        playerView.removeFromSuperview()
        playerView.translatesAutoresizingMaskIntoConstraints = true
        playerView.autoresizingMask = []
        playerView.frame = frameInWindow
        window.addSubview(playerView)
        playerView.isFullscreen = true
        let width = window.bounds.width
        let height = window.bounds.height
        // Rotate clockwise for landscapeLeft, counterclockwise for landscapeRight,
        // so the video appears right-side-up from the user's perspective.
        let angle: CGFloat = orientation == .landscapeLeft ? .pi / 2 : -.pi / 2
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            playerView.transform = CGAffineTransform(rotationAngle: angle)
            playerView.bounds = CGRect(x: 0, y: 0, width: height, height: width)
            playerView.center = CGPoint(x: width / 2, y: height / 2)
        }
    }

    func exitLandscapeFullscreen(playerView: VideoPlayerView) {
        guard let window = view.window,
              let snap = fullscreenSnapshot else {
            return
        }
        isLandscapeFullscreen = false
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        let target = snap.superview.convert(snap.frame, to: window)
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: .curveEaseInOut,
            animations: {
                playerView.transform = .identity
                playerView.bounds = CGRect(
                    origin: .zero,
                    size: target.size
                )
                playerView.center = CGPoint(
                    x: target.midX,
                    y: target.midY
                )
            },
            completion: { [weak self] _ in
                self?.restoreFromFullscreen(playerView: playerView, snapshot: snap)
            }
        )
    }
}
