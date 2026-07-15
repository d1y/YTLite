import AVKit
import UIKit

// MARK: - Picture in Picture

extension VideoPlayerView {
    /// Whether PiP is possible at all: device support + the user setting.
    var isPiPAvailable: Bool {
        let supported = AVPictureInPictureController
            .isPictureInPictureSupported()
        let enabled = UserDefaults.standard.object(
            forKey: UserDefaultsKeys.Player.pipEnabled
        ) as? Bool ?? true
        return supported && enabled
    }

    func setupPiP() {
        setControlAvailability(
            pipButton,
            available: isPiPAvailable
        )
        guard isPiPAvailable else {
            // Also drops a controller created before the user
            // disabled the setting — it would otherwise keep
            // serving the (reused) player layer.
            pipController = nil
            return
        }
        guard pipController == nil else {
            return
        }
        pipController = AVPictureInPictureController(
            playerLayer: playerLayer
        )
        pipController?.delegate = self
    }

    /// Decision snapshot for auto-PiP / retain-controller rules.
    func autoPiPState(isPlaying: Bool) -> AutoPiPDecision.State {
        AutoPiPDecision.makeState(
            isPiPSupported: AVPictureInPictureController
                .isPictureInPictureSupported(),
            isPiPAlreadyActive: pipController?.isPictureInPictureActive == true,
            isFullscreen: isFullscreen,
            isPlaying: isPlaying
        )
    }

    /// Auto-PiP on backgrounding: when Auto PiP is on, retain the controller
    /// for any playing video; when off, only fullscreen keeps it (legacy).
    /// Dropping the controller elsewhere prevents accidental system auto-PiP
    /// while still allowing background audio after layer detach.
    @objc
    func appWillResignActive() {
        guard pipController?.isPictureInPictureActive != true else {
            return
        }
        wasPlayingOnResign = (player?.rate ?? 0) > 0
        let state = autoPiPState(isPlaying: wasPlayingOnResign)
        if AutoPiPDecision.shouldRetainPiPControllerOnResign(state: state) {
            // Keep controller so we can start PiP or system may hand off.
            if AutoPiPDecision.shouldAutoStartPiP(state: state),
               let pip = pipController,
               pip.isPictureInPicturePossible {
                pip.startPictureInPicture()
            }
            return
        }
        pipController = nil
    }

    /// A real backgrounding: detach the layer (a layer-backed player is
    /// paused by iOS in the background) and, since without a controller the
    /// system may have paused playback during the transition, resume on the
    /// next tick — after every handler (incl. the mini bar's detach) ran.
    @objc
    func appDidEnterBackground() {
        if pipController?.isPictureInPictureActive == true {
            return
        }
        // Second chance for auto-PiP if resignActive didn't start it.
        let state = autoPiPState(isPlaying: wasPlayingOnResign)
        if AutoPiPDecision.shouldAutoStartPiP(state: state) {
            setupPiP()
            if let pip = pipController, pip.isPictureInPicturePossible {
                pip.startPictureInPicture()
                return
            }
        }
        guard BackgroundPlaybackService.isEnabled else {
            return
        }
        playerLayer.player = nil
        guard wasPlayingOnResign else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            if let player = self?.player, player.rate == 0 {
                player.play()
            }
        }
    }

    @objc
    func appDidBecomeActive() {
        guard let player else {
            return
        }
        if playerLayer.player == nil {
            playerLayer.player = player
        }
        // Re-evaluate the PiP setting (it may have changed in Settings).
        setupPiP()
    }

    @objc
    func pipTapped() {
        guard let pip = pipController else {
            return
        }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else {
            pip.startPictureInPicture()
        }
    }
}

// MARK: - PiP Delegate

extension VideoPlayerView: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        let size = ResponsiveMetrics.pipGlyphSize(forWidth: lastMetricsWidth)
        pipButton.setImage(
            PlayerIcons.pipExit(size: size),
            for: .normal
        )
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        let size = ResponsiveMetrics.pipGlyphSize(forWidth: lastMetricsWidth)
        pipButton.setImage(
            PlayerIcons.pip(size: size),
            for: .normal
        )
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler
            completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
