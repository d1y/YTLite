// swiftlint:disable file_length
import AVFoundation
import AVKit
import UIKit

// MARK: - Setup

extension VideoPlayerView {
    func performSetup() {
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
        topGradientLayer.opacity = 0
        bottomGradientLayer.opacity = 0
        layer.addSublayer(topGradientLayer)
        layer.addSublayer(bottomGradientLayer)
        setupControls()
        addGestureRecognizers()
        addLifecycleObservers()
    }

    /// Unavailable controls stay visible but disabled, so the top-bar
    /// layout never shifts and the user sees the feature exists.
    func setControlAvailability(_ button: UIButton, available: Bool) {
        button.isEnabled = available
        button.alpha = available ? 1 : 0.4
    }

    private func addLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    // MARK: - Gesture Recognizers

    private func addGestureRecognizers() {
        let doubleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap)
        )
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)

        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(handlePinch(_:))
        )
        addGestureRecognizer(pinch)

        let swipeDown = UISwipeGestureRecognizer(
            target: self,
            action: #selector(handleSwipeDown)
        )
        swipeDown.direction = .down
        addGestureRecognizer(swipeDown)
    }

    // MARK: - Controls Container

    func setupControls() {
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        controlsView.alpha = 0
        addSubview(controlsView)
        NSLayoutConstraint.activate([
            controlsView.topAnchor.constraint(
                equalTo: topAnchor
            ),
            controlsView.leadingAnchor.constraint(
                equalTo: leadingAnchor
            ),
            controlsView.trailingAnchor.constraint(
                equalTo: trailingAnchor
            ),
            controlsView.bottomAnchor.constraint(
                equalTo: bottomAnchor
            )
        ])
        setupDimOverlay()
        setupSpinner()
        setupSkipButtonTarget()
        setupTopBar()
        setupCenterButtons()
        setupBottomBar()
    }

    private func setupDimOverlay() {
        controlsView.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(
                equalTo: controlsView.topAnchor
            ),
            dimView.leadingAnchor.constraint(
                equalTo: controlsView.leadingAnchor
            ),
            dimView.trailingAnchor.constraint(
                equalTo: controlsView.trailingAnchor
            ),
            dimView.bottomAnchor.constraint(
                equalTo: controlsView.bottomAnchor
            )
        ])
    }

    private func setupSpinner() {
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(
                equalTo: centerXAnchor
            ),
            spinner.centerYAnchor.constraint(
                equalTo: centerYAnchor
            )
        ])
    }

    private func setupSkipButtonTarget() {
        skipButton.addTarget(
            self,
            action: #selector(skipButtonTapped),
            for: .touchUpInside
        )
        addSubview(skipButton)
        NSLayoutConstraint.activate([
            skipButton.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -16
            ),
            skipButton.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -72
            )
        ])
    }

    // MARK: - Top Bar

    private func setupTopBar() {
        settingsButton.setImage(
            PlayerIcons.settings(),
            for: .normal
        )
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(
            self,
            action: #selector(settingsTapped),
            for: .touchUpInside
        )
        controlsView.addSubview(settingsButton)
        configurePipButton()
        configureCCButton()
        configureSpeedButton()
        activateTopBarConstraints()
    }

    private func configurePipButton() {
        pipButton.setImage(
            PlayerIcons.pip(),
            for: .normal
        )
        pipButton.tintColor = .white
        pipButton.translatesAutoresizingMaskIntoConstraints = false
        pipButton.addTarget(
            self,
            action: #selector(pipTapped),
            for: .touchUpInside
        )
        MotionStyle.installPressFeedback(on: pipButton)
        setControlAvailability(
            pipButton,
            available: isPiPAvailable
        )
        controlsView.addSubview(pipButton)
    }

    private func configureCCButton() {
        styleCCButton()
        ccButton.translatesAutoresizingMaskIntoConstraints = false
        setControlAvailability(ccButton, available: false)
        ccButton.addTarget(
            self,
            action: #selector(ccTapped),
            for: .touchUpInside
        )
        controlsView.addSubview(ccButton)
        setupSubtitleLabel()
    }

    private func configureSpeedButton() {
        speedButton.tintColor = .white
        speedButton.titleLabel?.font = UIFont.systemFont(
            ofSize: 10,
            weight: .bold
        )
        speedButton.setTitleColor(.white, for: .normal)
        speedButton.layer.borderColor = UIColor.white
            .withAlphaComponent(0.6).cgColor
        speedButton.layer.borderWidth = 1
        speedButton.layer.cornerRadius = 4
        speedButton.translatesAutoresizingMaskIntoConstraints = false
        speedButton.addTarget(
            self,
            action: #selector(speedTapped),
            for: .touchUpInside
        )
        controlsView.addSubview(speedButton)
        setupSpeedOverlay()
        updateSpeedButtonTitle()
    }

    private func setupSpeedOverlay() {
        addSubview(speedOverlay)
        speedOverlay.addSubview(speedLabel)
        speedOverlay.addSubview(speedSlider)
        speedLabel.text = "Normal"
        speedSlider.addTarget(
            self,
            action: #selector(speedSliderChanged(_:)),
            for: .valueChanged
        )
        speedSlider.addTarget(
            self,
            action: #selector(speedSliderReleased(_:)),
            for: [.touchUpInside, .touchUpOutside]
        )
        activateSpeedOverlayConstraints()
    }

    private func activateSpeedOverlayConstraints() {
        NSLayoutConstraint.activate([
            speedOverlay.topAnchor.constraint(
                equalTo: speedButton.bottomAnchor,
                constant: 8
            ),
            speedOverlay.centerXAnchor.constraint(
                equalTo: speedButton.centerXAnchor
            ),
            speedOverlay.widthAnchor.constraint(
                equalToConstant: 220
            ),
            speedOverlay.heightAnchor.constraint(
                equalToConstant: 60
            )
        ])
        activateSpeedContentConstraints()
    }

    private func activateSpeedContentConstraints() {
        NSLayoutConstraint.activate([
            speedLabel.topAnchor.constraint(
                equalTo: speedOverlay.topAnchor,
                constant: 8
            ),
            speedLabel.centerXAnchor.constraint(
                equalTo: speedOverlay.centerXAnchor
            ),
            speedSlider.topAnchor.constraint(
                equalTo: speedLabel.bottomAnchor,
                constant: 4
            ),
            speedSlider.leadingAnchor.constraint(
                equalTo: speedOverlay.leadingAnchor,
                constant: 16
            ),
            speedSlider.trailingAnchor.constraint(
                equalTo: speedOverlay.trailingAnchor,
                constant: -16
            )
        ])
    }

    private func styleCCButton() {
        ccButton.setTitle("CC", for: .normal)
        ccButton.titleLabel?.font = UIFont.systemFont(
            ofSize: 12, weight: .bold
        )
        ccButton.tintColor = .white
        ccButton.setTitleColor(.white, for: .normal)
        ccButton.setTitleColor(
            UIColor(red: 1, green: 0.84, blue: 0, alpha: 1),
            for: .selected
        )
        ccButton.layer.borderColor = UIColor.white
            .withAlphaComponent(0.6).cgColor
        ccButton.layer.borderWidth = 1
        ccButton.layer.cornerRadius = 4
    }

    private func setupSubtitleLabel() {
        addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            subtitleLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: 16
            ),
            subtitleLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -16
            ),
            subtitleLabel.bottomAnchor.constraint(
                equalTo: bottomAnchor, constant: -56
            )
        ])
    }

    private func activateTopBarConstraints() {
        activateSettingsConstraints()
        activatePipConstraints()
        activateCCConstraints()
        activateSpeedConstraints()
    }

    private func activateSettingsConstraints() {
        let safeArea = controlsView.safeAreaLayoutGuide
        settingsWidthConstraint = settingsButton.widthAnchor.constraint(
            equalToConstant: 36
        )
        settingsHeightConstraint = settingsButton.heightAnchor.constraint(
            equalToConstant: 36
        )
        // Mac: nav minimize / traffic lights sit over the player top edge —
        // push chrome down so it doesn't collide with window controls.
        let topPad: CGFloat = PlatformStyle.isMac ? 48 : 20
        NSLayoutConstraint.activate([
            settingsButton.topAnchor.constraint(
                equalTo: safeArea.topAnchor, constant: topPad
            ),
            settingsButton.trailingAnchor.constraint(
                equalTo: safeArea.trailingAnchor, constant: -28
            ),
            settingsWidthConstraint!,
            settingsHeightConstraint!
        ])
    }

    private func activatePipConstraints() {
        pipWidthConstraint = pipButton.widthAnchor.constraint(
            equalToConstant: 36
        )
        pipHeightConstraint = pipButton.heightAnchor.constraint(
            equalToConstant: 36
        )
        pipTrailingGapConstraint = pipButton.trailingAnchor.constraint(
            equalTo: settingsButton.leadingAnchor,
            constant: -4
        )
        NSLayoutConstraint.activate([
            pipButton.centerYAnchor.constraint(
                equalTo: settingsButton.centerYAnchor
            ),
            pipTrailingGapConstraint!,
            pipWidthConstraint!,
            pipHeightConstraint!
        ])
    }

    private func activateCCConstraints() {
        ccWidthConstraint = ccButton.widthAnchor.constraint(
            equalToConstant: 32
        )
        ccHeightConstraint = ccButton.heightAnchor.constraint(
            equalToConstant: 22
        )
        ccTrailingGapConstraint = ccButton.trailingAnchor.constraint(
            equalTo: pipButton.leadingAnchor,
            constant: -4
        )
        NSLayoutConstraint.activate([
            ccButton.centerYAnchor.constraint(
                equalTo: settingsButton.centerYAnchor
            ),
            ccTrailingGapConstraint!,
            ccWidthConstraint!,
            ccHeightConstraint!
        ])
    }

    private func activateSpeedConstraints() {
        speedWidthConstraint = speedButton.widthAnchor.constraint(
            equalToConstant: 36
        )
        speedHeightConstraint = speedButton.heightAnchor.constraint(
            equalToConstant: 22
        )
        speedTrailingGapConstraint = speedButton.trailingAnchor.constraint(
            equalTo: ccButton.leadingAnchor,
            constant: -4
        )
        NSLayoutConstraint.activate([
            speedButton.centerYAnchor.constraint(
                equalTo: settingsButton.centerYAnchor
            ),
            speedTrailingGapConstraint!,
            speedWidthConstraint!,
            speedHeightConstraint!
        ])
    }

    // MARK: - Center Buttons

    private func setupCenterButtons() {
        configureRewindButton()
        configurePlayPauseButton()
        configureForwardButton()
        controlsView.addSubview(rewindButton)
        controlsView.addSubview(playPauseButton)
        controlsView.addSubview(forwardButton)
        activateCenterConstraints()
    }

    private func configureRewindButton() {
        rewindButton.setImage(
            PlayerIcons.rewind10(),
            for: .normal
        )
        rewindButton.tintColor = .white
        rewindButton.translatesAutoresizingMaskIntoConstraints = false
        rewindButton.addTarget(
            self,
            action: #selector(rewindTapped),
            for: .touchUpInside
        )
        MotionStyle.installPressFeedback(on: rewindButton)
    }

    private func configurePlayPauseButton() {
        playPauseButton.tintColor = .white
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(
            self,
            action: #selector(playPauseTapped),
            for: .touchUpInside
        )
        MotionStyle.installPressFeedback(on: playPauseButton)
        updatePlayPauseIcon()
    }

    private func configureForwardButton() {
        forwardButton.setImage(
            PlayerIcons.forward10(),
            for: .normal
        )
        forwardButton.tintColor = .white
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        forwardButton.addTarget(
            self,
            action: #selector(forwardTapped),
            for: .touchUpInside
        )
        MotionStyle.installPressFeedback(on: forwardButton)
    }

    private func activateCenterConstraints() {
        playPauseWidthConstraint = playPauseButton.widthAnchor.constraint(
            equalToConstant: 52
        )
        playPauseHeightConstraint = playPauseButton.heightAnchor.constraint(
            equalToConstant: 52
        )
        NSLayoutConstraint.activate([
            playPauseButton.centerXAnchor.constraint(
                equalTo: controlsView.centerXAnchor
            ),
            playPauseButton.centerYAnchor.constraint(
                equalTo: controlsView.centerYAnchor
            ),
            playPauseWidthConstraint!,
            playPauseHeightConstraint!
        ])
        activateSkipButtonConstraints()
    }

    private func activateSkipButtonConstraints() {
        skipSpacingLeadingConstraint = rewindButton.trailingAnchor.constraint(
            equalTo: playPauseButton.leadingAnchor,
            constant: -32
        )
        skipSpacingTrailingConstraint = forwardButton.leadingAnchor.constraint(
            equalTo: playPauseButton.trailingAnchor,
            constant: 32
        )
        rewindWidthConstraint = rewindButton.widthAnchor.constraint(
            equalToConstant: 44
        )
        rewindHeightConstraint = rewindButton.heightAnchor.constraint(
            equalToConstant: 44
        )
        forwardWidthConstraint = forwardButton.widthAnchor.constraint(
            equalToConstant: 44
        )
        forwardHeightConstraint = forwardButton.heightAnchor.constraint(
            equalToConstant: 44
        )
        NSLayoutConstraint.activate([
            rewindButton.centerYAnchor.constraint(
                equalTo: playPauseButton.centerYAnchor
            ),
            skipSpacingLeadingConstraint!,
            rewindWidthConstraint!,
            rewindHeightConstraint!,
            forwardButton.centerYAnchor.constraint(
                equalTo: playPauseButton.centerYAnchor
            ),
            skipSpacingTrailingConstraint!,
            forwardWidthConstraint!,
            forwardHeightConstraint!
        ])
    }

    /// Scales transport + top chrome controls for large windows.
    /// **Skips** when width bucket unchanged — called from Watch
    /// `viewDidLayoutSubviews` every frame; re-rasterizing glyphs each time
    /// caused 0x8BADF00D (PlayerIcons.playerIcon / UIGraphicsImageRenderer).
    func applyResponsiveControlMetrics(forWidth width: CGFloat) {
        guard width > 1 else {
            return
        }
        if lastMetricsWidth > 0, abs(width - lastMetricsWidth) < 0.5 {
            return
        }
        lastMetricsWidth = width
        let play = ResponsiveMetrics.playControlSize(forWidth: width)
        let skip = ResponsiveMetrics.skipControlSize(forWidth: width)
        let gap = max(24, play * 0.55)
        playPauseWidthConstraint?.constant = play
        playPauseHeightConstraint?.constant = play
        rewindWidthConstraint?.constant = skip
        rewindHeightConstraint?.constant = skip
        forwardWidthConstraint?.constant = skip
        forwardHeightConstraint?.constant = skip
        skipSpacingLeadingConstraint?.constant = -gap
        skipSpacingTrailingConstraint?.constant = gap

        // Top row: speed / CC / PiP / settings — grow hit targets + spacing.
        let hit = ResponsiveMetrics.topControlHitSize(forWidth: width)
        let topGap = -ResponsiveMetrics.topControlSpacing(forWidth: width)
        let chipH = max(22, hit * 0.58)
        let chipW = max(32, hit * 0.95)
        settingsWidthConstraint?.constant = hit
        settingsHeightConstraint?.constant = hit
        pipWidthConstraint?.constant = hit
        pipHeightConstraint?.constant = hit
        ccWidthConstraint?.constant = chipW
        ccHeightConstraint?.constant = chipH
        speedWidthConstraint?.constant = chipW
        speedHeightConstraint?.constant = chipH
        pipTrailingGapConstraint?.constant = topGap
        ccTrailingGapConstraint?.constant = topGap
        speedTrailingGapConstraint?.constant = topGap

        let labelSize = ResponsiveMetrics.chromeLabelPointSize(forWidth: width)
        speedButton.titleLabel?.font = UIFont.systemFont(
            ofSize: max(10, labelSize - 3),
            weight: .bold
        )
        ccButton.titleLabel?.font = UIFont.systemFont(
            ofSize: max(11, labelSize - 2),
            weight: .bold
        )

        reapplyScaledGlyphs(forWidth: width)
        installPointerHoverIfNeeded()
        MacPointerHover.install(on: [
            playPauseButton, rewindButton, forwardButton,
            settingsButton, pipButton, ccButton, speedButton, fullscreenButton
        ])
    }

    /// Re-setImage with size-aware PlayerIcons (cached rasters).
    func reapplyScaledGlyphs(forWidth width: CGFloat) {
        let play = ResponsiveMetrics.playControlSize(forWidth: width)
        let skip = ResponsiveMetrics.skipControlSize(forWidth: width)
        let settings = ResponsiveMetrics.settingsGlyphSize(forWidth: width)
        let pip = ResponsiveMetrics.pipGlyphSize(forWidth: width)
        let full = ResponsiveMetrics.fullscreenGlyphSize(forWidth: width)

        let isPlaying = (player?.rate ?? 0) > 0
        playPauseButton.setImage(
            isPlaying
                ? PlayerIcons.pause(size: play)
                : PlayerIcons.play(size: play),
            for: .normal
        )
        rewindButton.setImage(PlayerIcons.rewind10(size: skip), for: .normal)
        forwardButton.setImage(PlayerIcons.forward10(size: skip), for: .normal)
        settingsButton.setImage(PlayerIcons.settings(size: settings), for: .normal)

        let pipActive = pipController?.isPictureInPictureActive == true
        pipButton.setImage(
            pipActive
                ? PlayerIcons.pipExit(size: pip)
                : PlayerIcons.pip(size: pip),
            for: .normal
        )
        fullscreenButton.setImage(
            PlayerIcons.fullscreen(isFullscreen: isFullscreen, size: full),
            for: .normal
        )
    }

    private func installPointerHoverIfNeeded() {
        guard ResponsiveMetrics.shouldInstallPointerHover(
            isMac: PlatformStyle.isMac
        ), !didInstallPointerHover else {
            return
        }
        didInstallPointerHover = true
        let targets: [UIView] = [
            playPauseButton,
            rewindButton,
            forwardButton,
            settingsButton,
            pipButton,
            ccButton,
            speedButton,
            fullscreenButton
        ]
        for target in targets {
            if #available(iOS 13.4, *) {
                target.addInteraction(
                    UIPointerInteraction(delegate: PlayerPointerRelay.shared)
                )
            }
            if #available(iOS 13.0, *) {
                let hover = UIHoverGestureRecognizer(
                    target: self,
                    action: #selector(handleControlHover(_:))
                )
                target.addGestureRecognizer(hover)
            }
        }
    }

    @available(iOS 13.0, *)
    @objc
    private func handleControlHover(_ gesture: UIHoverGestureRecognizer) {
        guard let view = gesture.view else { return }
        switch gesture.state {
        case .began, .changed:
            UIView.animate(withDuration: 0.12) {
                view.alpha = 1
                view.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            }
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.12) {
                view.transform = .identity
            }
        default:
            break
        }
    }
}

@available(iOS 13.4, *)
private final class PlayerPointerRelay: NSObject, UIPointerInteractionDelegate {
    static let shared = PlayerPointerRelay()

    func pointerInteraction(
        _ interaction: UIPointerInteraction,
        styleFor region: UIPointerRegion
    ) -> UIPointerStyle? {
        guard let view = interaction.view else { return nil }
        return UIPointerStyle(effect: .highlight(UITargetedPreview(view: view)))
    }
}
