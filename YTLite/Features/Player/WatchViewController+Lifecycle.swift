import UIKit

// MARK: - Lifecycle

extension WatchViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Window is live — safe to bind AppKit observers.
        installMacWindowObserversIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Avoid layout thrash while the player is window-hosted.
        if fullscreenSnapshot == nil {
            updateLayoutForSize()
            adjustForFloatingNavBar()
            if PlatformStyle.isMac, macCloseControlInstalled {
                view.bringSubviewToFront(macCloseControl)
            }
        } else if PlatformStyle.isMac {
            layoutMacFullscreenIfValid()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let isDismissing = isMovingFromParent
            || isBeingDismissed
            || navigationController?.isBeingDismissed == true
        if isDismissing {
            pageLoadToken.cancel()
            videoPlayerView?.player?.pause()
        }
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        // Mac app-fullscreen + green traffic light / system zoom.
        if PlatformStyle.isMac, fullscreenSnapshot != nil {
            handleMacFullscreenSizeTransition(to: size, coordinator: coordinator)
            return
        }
        animateLayoutTransition(to: size, coordinator: coordinator)
    }

    private func layoutMacFullscreenIfValid() {
        guard let window = view.window,
              ResponsiveMetrics.isValidFullscreenHostBounds(window.bounds.size)
        else {
            return
        }
        syncFullscreenPlayerFrame(in: window)
        window.bringSubviewToFront(macCloseControl)
    }

    private func animateLayoutTransition(
        to size: CGSize,
        coordinator: UIViewControllerTransitionCoordinator
    ) {
        coordinator.animate(
            alongsideTransition: { [weak self] _ in
                guard let self else {
                    return
                }
                if fullscreenSnapshot != nil {
                    syncFullscreenPlayerFrame()
                } else {
                    updateLayoutForSize(size)
                }
                view.layoutIfNeeded()
            },
            completion: { [weak self] _ in
                guard let self else {
                    return
                }
                if fullscreenSnapshot != nil {
                    DispatchQueue.main.async { [weak self] in
                        self?.syncFullscreenPlayerFrame()
                        self?.recoverMacFullscreenIfNeeded()
                    }
                } else {
                    updateLayoutForSize()
                }
            }
        )
    }
}
