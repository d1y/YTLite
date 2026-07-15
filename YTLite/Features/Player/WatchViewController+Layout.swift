// swiftlint:disable file_length
import UIKit

extension WatchViewController {
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        adjustForFloatingNavBar()
    }

    func setupNavigationBar() {
        if PlatformStyle.isMac {
            // Mac: system nav bar is useless for close (titlebar + chevron clip).
            // Hide it and use a floating control clear of traffic lights.
            title = nil
            navigationItem.title = ""
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.leftBarButtonItem = nil
            navigationItem.hidesBackButton = true
            navigationController?.setNavigationBarHidden(true, animated: false)
            navigationController?.navigationBar.isHidden = true
            installMacCloseControlIfNeeded()
        } else {
            navigationController?.setNavigationBarHidden(false, animated: false)
            updateLeftBarButton()
        }
        MacPointerHover.install(on: [
            likeButton, dislikeButton, shareButton,
            saveButton, downloadButton, subscribeButton,
            descriptionButton, loadMoreCommentsButton
        ])
    }

    /// Circular floating close control for Mac watch (back or minimize).
    /// Must not call `updateMacCloseControlAppearance` (that used to recurse
    /// and stack-overflow on every watch open — SIGSEGV).
    func installMacCloseControlIfNeeded() {
        guard PlatformStyle.isMac else {
            return
        }
        if !macCloseControlInstalled {
            macCloseControlInstalled = true
            configureMacCloseControlChrome()
            pinMacCloseControl(to: view, useSafeAreaTop: true)
        } else if macCloseControl.superview == nil {
            pinMacCloseControl(to: view, useSafeAreaTop: true)
        }
        applyMacCloseControlAppearanceOnly()
    }

    private func configureMacCloseControlChrome() {
        // Same floating style as search + playlist NavChevron.
        NavChevron.applyMacFloatingStyle(
            to: macCloseControl,
            kind: .back,
            theme: ThemeManager.shared,
            side: NavChevron.macFloatingSide
        )
        macCloseControl.accessibilityIdentifier = "watch.macClose"
        macCloseControl.addTarget(
            self,
            action: #selector(closeTapped),
            for: .touchUpInside
        )
        MotionStyle.installPressFeedback(on: macCloseControl)
        MacPointerHover.install(on: macCloseControl)
    }

    /// Pin floating close to a host (watch view or window during fullscreen).
    /// Placement: **below** traffic lights, leading margin 16, icon always `<`.
    func pinMacCloseControl(to host: UIView, useSafeAreaTop: Bool) {
        let leading = ResponsiveMetrics.macWatchCloseLeadingInset()
        let topConstant = ResponsiveMetrics.macWatchCloseTopInset()
        if updateMacClosePinIfReusable(
            host: host,
            leading: leading,
            topConstant: topConstant
        ) {
            return
        }
        installMacClosePin(
            on: host,
            leading: leading,
            topConstant: topConstant
        )
        _ = useSafeAreaTop
    }

    private func updateMacClosePinIfReusable(
        host: UIView,
        leading: CGFloat,
        topConstant: CGFloat
    ) -> Bool {
        guard macCloseControl.superview === host,
              let leadC = macCloseLeadingConstraint,
              let topC = macCloseTopConstraint,
              leadC.isActive, topC.isActive
        else {
            return false
        }
        leadC.constant = leading
        topC.constant = topConstant
        host.bringSubviewToFront(macCloseControl)
        macCloseControl.isHidden = false
        return true
    }

    private func installMacClosePin(
        on host: UIView,
        leading: CGFloat,
        topConstant: CGFloat
    ) {
        let side = ResponsiveMetrics.macSearchControlHeight()
        if macCloseControl.superview != nil {
            macCloseControl.removeFromSuperview()
        }
        macCloseControl.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(macCloseControl)
        NSLayoutConstraint.deactivate(
            [
                macCloseLeadingConstraint, macCloseTopConstraint,
                macCloseWidthConstraint, macCloseHeightConstraint
            ].compactMap { $0 }
        )
        let lead = macCloseControl.leadingAnchor.constraint(
            equalTo: host.leadingAnchor, constant: leading
        )
        let top = macCloseControl.topAnchor.constraint(
            equalTo: host.topAnchor, constant: topConstant
        )
        let width = macCloseControl.widthAnchor.constraint(equalToConstant: side)
        let height = macCloseControl.heightAnchor.constraint(equalToConstant: side)
        macCloseLeadingConstraint = lead
        macCloseTopConstraint = top
        macCloseWidthConstraint = width
        macCloseHeightConstraint = height
        NSLayoutConstraint.activate([lead, top, width, height])
        host.bringSubviewToFront(macCloseControl)
        macCloseControl.isHidden = false
    }

    /// Public entry: ensure installed then refresh icon (no recursion).
    func updateMacCloseControlAppearance() {
        guard PlatformStyle.isMac else {
            return
        }
        if !macCloseControlInstalled {
            installMacCloseControlIfNeeded()
            return
        }
        applyMacCloseControlAppearanceOnly()
    }

    /// Icon / colors only — always chevron.left (`<`), playlist-matched style.
    private func applyMacCloseControlAppearanceOnly() {
        NavChevron.applyMacFloatingStyle(
            to: macCloseControl,
            kind: .back,
            theme: ThemeManager.shared,
            side: NavChevron.macFloatingSide
        )
        macCloseControl.accessibilityLabel = videoHistory.isEmpty ? "Close" : "Back"
        if let host = macCloseControl.superview {
            host.bringSubviewToFront(macCloseControl)
        }
        macCloseControl.isHidden = false
    }

    func addNotificationObservers() {
        let nc = NotificationCenter.default
        let tn = ThemeManager.didChangeNotification
        let bg = UIApplication.didEnterBackgroundNotification
        let fg = UIApplication.willEnterForegroundNotification
        nc.addObserver(self, selector: #selector(applyTheme), name: tn, object: nil)
        nc.addObserver(self, selector: #selector(appDidEnterBackground), name: bg, object: nil)
        nc.addObserver(self, selector: #selector(appWillEnterForeground), name: fg, object: nil)
        // On iPhone the interface is portrait-locked; handle landscape fullscreen
        // by observing raw device orientation changes instead of relying on rotation.
        if UIDevice.current.userInterfaceIdiom != .pad {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            nc.addObserver(
                self,
                selector: #selector(handleDeviceOrientationChange),
                name: UIDevice.orientationDidChangeNotification,
                object: nil
            )
        }
    }

    func setupLayout() {
        setupScrollAndPlayer()
        setupPlayerOverlays()
        setupMetaViews()
        setupChannelViews()
        setupActionBar()
        setupCommentsSection()
        setupRelatedCollection()
        activateMetaConstraints()
        activateChannelConstraints()
        activateBottomConstraints()
        let sel = #selector(openChannel)
        channelAvatarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: sel))
        channelNameLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: sel))
    }

    func setupScrollAndPlayer() {
        for item in [scrollView, playerContainer, sidebarContainer, contentView] {
            item.translatesAutoresizingMaskIntoConstraints = false
        }
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.panGestureRecognizer.cancelsTouchesInView = false
        scrollView.delegate = self
        [scrollView, playerContainer, sidebarContainer].forEach { view.addSubview($0) }
        scrollView.addSubview(contentView)
        let pc = playerContainer, sv = scrollView
        let sc = sidebarContainer, safe = view.safeAreaLayoutGuide
        scrollTrailingConstraint = sv.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        scrollToSidebarConstraint = sv.trailingAnchor.constraint(equalTo: sc.leadingAnchor)
        playerTopConstraint = pc.topAnchor.constraint(equalTo: safe.topAnchor)
        // Use safe area for leading so content respects rounded corners in iPhone landscape.
        // In portrait there is no horizontal safe area inset so this is equivalent to
        // view.leadingAnchor on both iPhone and iPad.
        playerLeadingConstraint = pc.leadingAnchor.constraint(equalTo: safe.leadingAnchor)
        playerTrailingConstraint = pc.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        playerToSidebarConstraint = pc.trailingAnchor.constraint(equalTo: sc.leadingAnchor)
        playerAspectConstraint = pc.heightAnchor.constraint(
            equalTo: pc.widthAnchor,
            multiplier: 9.0 / 16.0
        )
        scrollTopToPlayerConstraint = sv.topAnchor.constraint(equalTo: pc.bottomAnchor)
        sidebarTopConstraint = sc.topAnchor.constraint(equalTo: safe.topAnchor)
        // Respect right safe area so sidebar content clears the rounded corner on iPhone landscape.
        sidebarTrailingConstraint = sc.trailingAnchor.constraint(equalTo: safe.trailingAnchor)
        sidebarBottomConstraint = sc.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        sidebarWidthConstraint = sc.widthAnchor.constraint(equalToConstant: 340)
        activateScrollConstraints()
    }

    func activateScrollConstraints() {
        let cv = contentView, sv = scrollView
        let cl = sv.contentLayoutGuide, fl = sv.frameLayoutGuide
        NSLayoutConstraint.activate(
            [
                playerTopConstraint, playerLeadingConstraint,
                playerTrailingConstraint, playerAspectConstraint,
                scrollTopToPlayerConstraint, scrollTrailingConstraint,
                // Use safe area for leading to match playerLeadingConstraint so the
                // scroll content aligns with the player edge on iPhone landscape.
                sv.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                sv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                cv.topAnchor.constraint(equalTo: cl.topAnchor),
                cv.leadingAnchor.constraint(equalTo: cl.leadingAnchor),
                cv.trailingAnchor.constraint(equalTo: cl.trailingAnchor),
                cv.bottomAnchor.constraint(equalTo: cl.bottomAnchor),
                cv.widthAnchor.constraint(equalTo: fl.widthAnchor)
            ].compactMap { $0 }
        )
    }

    func setupPlayerOverlays() {
        let ps = playerSpinner, sl = playerStatusLabel, pc = playerContainer
        [ps, sl].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        ps.startAnimating()
        pc.addSubview(ps)
        sl.text = "Preparing video..."
        sl.textAlignment = .center
        sl.numberOfLines = 0
        sl.font = UIFont.systemFont(ofSize: 14)
        pc.addSubview(sl)
        NSLayoutConstraint.activate([
            ps.centerXAnchor.constraint(equalTo: pc.centerXAnchor),
            ps.centerYAnchor.constraint(equalTo: pc.centerYAnchor, constant: -10),
            sl.topAnchor.constraint(equalTo: ps.bottomAnchor, constant: 14),
            sl.leadingAnchor.constraint(equalTo: pc.leadingAnchor, constant: 24),
            sl.trailingAnchor.constraint(equalTo: pc.trailingAnchor, constant: -24)
        ])
    }

    func setupMetaViews() {
        let cv = contentView
        for item in [titleLabel, metaLabel, descriptionLabel, descriptionButton] {
            item.translatesAutoresizingMaskIntoConstraints = false
        }
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.numberOfLines = 0
        cv.addSubview(titleLabel)
        metaLabel.font = UIFont.systemFont(ofSize: 13)
        metaLabel.numberOfLines = 0
        cv.addSubview(metaLabel)
        descriptionLabel.font = UIFont.systemFont(ofSize: 13)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.isHidden = true
        cv.addSubview(descriptionLabel)
        descriptionButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        descriptionButton.addTarget(self, action: #selector(toggleDescription), for: .touchUpInside)
        descriptionButton.setTitle("More", for: .normal)
        cv.addSubview(descriptionButton)
    }

    func setupChannelViews() {
        let cv = contentView
        for item in [channelAvatarView, channelNameLabel, channelMetaLabel, subscribeButton] {
            item.translatesAutoresizingMaskIntoConstraints = false
        }
        channelAvatarView.layer.cornerRadius = 22
        channelAvatarView.layer.masksToBounds = true
        channelAvatarView.isUserInteractionEnabled = true
        cv.addSubview(channelAvatarView)
        channelNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        channelNameLabel.isUserInteractionEnabled = true
        cv.addSubview(channelNameLabel)
        channelMetaLabel.font = UIFont.systemFont(ofSize: 12)
        channelMetaLabel.numberOfLines = 2
        cv.addSubview(channelMetaLabel)
        subscribeButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        subscribeButton.layer.cornerRadius = 18
        subscribeButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        subscribeButton.isEnabled = !OAuthClient.shared.isAnonymous
        let sel = #selector(subscribeButtonTapped)
        subscribeButton.addTarget(self, action: sel, for: .touchUpInside)
        cv.addSubview(subscribeButton)
    }

    func setupActionBar() {
        actionBar.axis = .horizontal
        actionBar.distribution = .fillEqually
        actionBar.spacing = 8
        actionBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionBar)
        buildActionBarItems()
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        likeButton.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)
        dislikeButton.addTarget(self, action: #selector(dislikeTapped), for: .touchUpInside)
    }

    private func buildActionBarItems() {
        let items: [ActionBarItem] = [
            ActionBarItem(
                button: likeButton,
                icon: "icon_thumb_up",
                label: nil,
                countLabel: likeCountLabel
            ),
            ActionBarItem(
                button: dislikeButton,
                icon: "icon_thumb_down",
                label: nil,
                countLabel: dislikeCountLabel
            ),
            ActionBarItem(button: shareButton, icon: "icon_share", label: "Share"),
            ActionBarItem(button: saveButton, icon: "icon_bookmark", label: "Save"),
            ActionBarItem(button: downloadButton, icon: "icon_download", label: "Download")
        ]
        for item in items {
            actionBar.addArrangedSubview(
                makeActionItem(
                    btn: item.button,
                    iconName: item.icon,
                    staticLabel: item.label,
                    countLabel: item.countLabel
                )
            )
        }
    }

    func makeActionItem(
        btn: UIButton,
        iconName: String,
        staticLabel: String?,
        countLabel: UILabel? = nil
    )
        -> UIStackView {
        // Stash asset name so responsive typography can re-render glyphs.
        btn.accessibilityIdentifier = iconName
        let initial = ResponsiveMetrics.actionBarIconSize(forWidth: 390)
        if let rendered = PlayerIcons.actionBarIcon(named: iconName, size: initial) {
            btn.setImage(rendered, for: .normal)
        }
        btn.tintColor = ThemeManager.shared.primaryText
        btn.translatesAutoresizingMaskIntoConstraints = false
        let height = btn.heightAnchor.constraint(equalToConstant: initial + 6)
        height.identifier = "actionBarIconHeight"
        height.isActive = true
        let label = countLabel ?? UILabel()
        label.font = UIFont.systemFont(ofSize: 11)
        label.textAlignment = .center
        label.textColor = ThemeManager.shared.secondaryText
        label.text = staticLabel ?? "—"
        label.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView(arrangedSubviews: [btn, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    func setupCommentsSection() {
        let cv = contentView
        for item in [commentsLabel, commentsStackView, loadMoreCommentsButton] {
            item.translatesAutoresizingMaskIntoConstraints = false
        }
        commentsLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        commentsLabel.text = "Comments"
        cv.addSubview(commentsLabel)
        commentsStackView.axis = .vertical
        commentsStackView.spacing = 12
        cv.addSubview(commentsStackView)
        loadMoreCommentsButton.contentHorizontalAlignment = .left
        loadMoreCommentsButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        loadMoreCommentsButton.setTitle("Load more comments", for: .normal)
        loadMoreCommentsButton.addTarget(
            self,
            action: #selector(loadMoreCommentsTapped),
            for: .touchUpInside
        )
        cv.addSubview(loadMoreCommentsButton)
    }

    func setupRelatedCollection() {
        let rv = relatedCollectionView
        rv.register(VideoCell.self, forCellWithReuseIdentifier: VideoCell.reuseId)
        rv.register(
            PlaylistSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView
                .elementKindSectionHeader,
            withReuseIdentifier:
            PlaylistSectionHeaderView.reuseIdentifier
        )
        rv.dataSource = self
        rv.delegate = self
        rv.translatesAutoresizingMaskIntoConstraints = false
        rv.isScrollEnabled = false
        // Disable automatic inset adjustment: in portrait the outer scroll view manages
        // all scrolling; in landscape the sidebar is already positioned below the nav bar
        // via safeAreaLayoutGuide, so automatic adjustment would add a redundant top inset
        // that pushes the first related video down or off-screen.
        rv.contentInsetAdjustmentBehavior = .never
        contentView.addSubview(rv)
        relatedHeightConstraint = rv.heightAnchor.constraint(equalToConstant: 0)
    }

    /// On iOS 26+ the Liquid Glass nav bar no longer contributes its
    /// height to `view.safeAreaInsets`.  We measure the gap between the
    /// nav-bar bottom and the raw safe-area top, then push the player
    /// container down via `playerTopConstraint.constant` so it always
    /// starts below the navigation bar.
    func adjustForFloatingNavBar() {
        // Mac: no floating-nav offset — player sits under the unified title
        // bar so the watch surface can go edge-to-edge (no black strip).
        if PlatformStyle.isMac {
            clearFloatingNavBarOffset()
            return
        }
        guard let navBar = navigationController?.navigationBar,
              !navBar.isHidden
        else {
            clearFloatingNavBarOffset()
            return
        }
        let navBarBottom = navBar.convert(
            CGPoint(x: 0, y: navBar.bounds.height),
            to: view
        ).y
        let safeTop = view.safeAreaInsets.top
            - additionalSafeAreaInsets.top
        let offset = max(0, navBarBottom - safeTop)
        if abs(additionalSafeAreaInsets.top - 0) > 0.5 {
            additionalSafeAreaInsets.top = 0
        }
        if abs((playerTopConstraint?.constant ?? 0) - offset) > 0.5 {
            playerTopConstraint?.constant = offset
        }
    }

    private func clearFloatingNavBarOffset() {
        if additionalSafeAreaInsets.top != 0 {
            additionalSafeAreaInsets.top = 0
        }
        if playerTopConstraint?.constant != 0 {
            playerTopConstraint?.constant = 0
        }
    }
}

// MARK: - iPhone landscape rotation → auto-fullscreen

extension WatchViewController {
    @objc
    func handleDeviceOrientationChange() {
        let orientation = UIDevice.current.orientation
        guard let playerView = videoPlayerView else {
            return
        }
        if orientation.isLandscape, !isLandscapeFullscreen {
            enterLandscapeFullscreen(
                playerView: playerView,
                orientation: orientation
            )
        } else if orientation == .portrait, isLandscapeFullscreen {
            exitLandscapeFullscreen(playerView: playerView)
        }
    }
}

struct ActionBarItem {
    let button: UIButton
    let icon: String
    let label: String?
    var countLabel: UILabel?
}
