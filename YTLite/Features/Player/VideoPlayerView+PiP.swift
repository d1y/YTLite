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

    /// Auto-PiP on backgrounding is wanted only in fullscreen (with the
    /// setting on) — that case keeps its controller. Everywhere else only
    /// the controller is dropped here: that alone prevents auto-PiP at the
    /// transition, and keeping the layer attached means a Control Center /
    /// Notification Center peek (which fires resignActive but never
    /// didEnterBackground) doesn't touch the pipeline — no audio hiccup.
    @objc
    func appWillResignActive() {
        guard pipController?.isPictureInPictureActive != true else {
            return
        }
        wasPlayingOnResign = (player?.rate ?? 0) > 0
        if !isFullscreen {
            pipController = nil
        }
    }

    /// A real backgrounding: detach the layer (a layer-backed player is
    /// paused by iOS in the background) and, since without a controller the
    /// system may have paused playback during the transition, resume on the
    /// next tick — after every handler (incl. the mini bar's detach) ran.
    @objc
    func appDidEnterBackground() {
        guard pipController?.isPictureInPictureActive != true,
              BackgroundPlaybackService.isEnabled
        else {
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
        pipButton.setImage(
            PlayerIcons.pipExit(),
            for: .normal
        )
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        pipButton.setImage(
            PlayerIcons.pip(),
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
