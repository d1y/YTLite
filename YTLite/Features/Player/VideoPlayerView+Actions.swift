import AVFoundation
import AVKit
import UIKit

// MARK: - Gesture Handling

extension VideoPlayerView {
    @objc
    func handleTap() {
        if controlsVisible {
            setControls(visible: false, animated: true)
        } else {
            setControls(visible: true, animated: true)
            scheduleAutoHide()
        }
    }

    @objc
    func handleDoubleTap(
        _ gesture: UITapGestureRecognizer
    ) {
        let xPosition = gesture.location(in: self).x
        if xPosition < bounds.width / 2 {
            rewindTapped()
        } else {
            forwardTapped()
        }
        if !controlsVisible {
            setControls(visible: true, animated: true)
        }
        scheduleAutoHide()
    }

    @objc
    func handlePinch(
        _ gesture: UIPinchGestureRecognizer
    ) {
        guard gesture.state == .ended else {
            return
        }
        if gesture.scale > 1.2, !isFullscreen {
            delegate?.videoPlayerViewDidTapFullscreen(self)
        } else if gesture.scale < 0.8, isFullscreen {
            delegate?.videoPlayerViewDidTapFullscreen(self)
        }
    }

    @objc
    func handleSwipeDown() {
        guard isFullscreen else {
            return
        }
        delegate?.videoPlayerViewDidTapFullscreen(self)
    }
}

// MARK: - Controls Visibility

extension VideoPlayerView {
    func setControls(visible: Bool, animated: Bool) {
        controlsVisible = visible
        let targetAlpha: CGFloat = visible ? 1 : 0
        let animDuration = animated ? 0.2 : 0
        UIView.animate(withDuration: animDuration) {
            self.controlsView.alpha = targetAlpha
            self.topGradientLayer.opacity = visible
                ? 1
                : 0
            self.bottomGradientLayer.opacity = visible
                ? 1
                : 0
        }
        if !visible {
            speedOverlay.isHidden = true
        }
    }

    func scheduleAutoHide() {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self,
                  self.player?.rate ?? 0 > 0
            else {
                return
            }
            self.setControls(
                visible: false,
                animated: true
            )
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 3,
            execute: item
        )
    }

    func pauseAutoHide() {
        hideWorkItem?.cancel()
    }
}

// MARK: - Button Actions

extension VideoPlayerView {
    @objc
    func playPauseTapped() {
        guard let player else {
            return
        }
        if ResponsiveMetrics.isPlayerActivelyPlaying(rate: player.rate) {
            // Fast path: play → pause must be instant. Do not wait on
            // buffering / prepare-to-play work that only matters for resume.
            // Set rate first, then pause, then paint the icon synchronously.
            player.rate = 0
            player.pause()
            spinner.stopAnimating()
            setCenter(hidden: false)
            updatePlayPauseIcon()
        } else {
            // Resume may still buffer; show spinner via timeControlStatus KVO.
            if abs(playbackSpeed - 1.0) > 0.01 {
                player.rate = playbackSpeed
            } else {
                player.play()
            }
            // Optimistic icon — KVO will reaffirm when rate settles.
            updatePlayPauseIcon()
        }
        scheduleAutoHide()
    }

    @objc
    func rewindTapped() {
        guard let player else {
            return
        }
        let offset = CMTime(
            seconds: 10,
            preferredTimescale: 600
        )
        let newTime = max(
            player.currentTime() - offset,
            .zero
        )
        player.seek(
            to: newTime,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        scheduleAutoHide()
    }

    @objc
    func forwardTapped() {
        guard let player else {
            return
        }
        let offset = CMTime(
            seconds: 10,
            preferredTimescale: 600
        )
        let newTime = player.currentTime() + offset
        player.seek(
            to: newTime,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        scheduleAutoHide()
    }

    @objc
    func skipButtonTapped() {
        onSkipTapped?()
    }

    @objc
    func settingsTapped() {
        delegate?.videoPlayerViewDidTapSettings(self)
        scheduleAutoHide()
    }

    @objc
    func fullscreenTapped() {
        delegate?.videoPlayerViewDidTapFullscreen(self)
    }
}

// MARK: - Icon Updates

extension VideoPlayerView {
    func updatePlayPauseIcon() {
        let isPlaying = (player?.rate ?? 0) > 0
        let size = ResponsiveMetrics.playControlSize(forWidth: lastMetricsWidth)
        let icon = isPlaying
            ? PlayerIcons.pause(size: size)
            : PlayerIcons.play(size: size)
        playPauseButton.setImage(icon, for: .normal)
    }

    func updateFullscreenIcon() {
        let size = ResponsiveMetrics.fullscreenGlyphSize(forWidth: lastMetricsWidth)
        fullscreenButton.setImage(
            PlayerIcons.fullscreen(
                isFullscreen: isFullscreen,
                size: size
            ),
            for: .normal
        )
    }

    func setCenter(hidden: Bool) {
        playPauseButton.isHidden = hidden
        rewindButton.isHidden = hidden
        forwardButton.isHidden = hidden
    }
}
