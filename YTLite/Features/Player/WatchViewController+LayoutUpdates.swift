import UIKit

extension WatchViewController {
    func updateLayoutForSize(_ size: CGSize? = nil) {
        // While in fullscreen the player view lives in the window, not in our
        // view hierarchy — skip layout until the user exits fullscreen.
        guard fullscreenSnapshot == nil else {
            return
        }
        // Re-entrancy: layoutIfNeeded from here used to re-enter via
        // viewDidLayoutSubviews and thrash icon rasterization (0x8BADF00D).
        guard !isUpdatingWatchLayout else {
            return
        }
        isUpdatingWatchLayout = true
        defer { isUpdatingWatchLayout = false }

        let resolved = size ?? view.bounds.size
        guard resolved.width > 1, resolved.height > 1 else {
            return
        }
        let useSidebar = ResponsiveMetrics.prefersWatchSidebar(
            containerWidth: resolved.width,
            containerHeight: resolved.height
        )
        if useSidebar {
            activateLandscapeLayout()
        } else {
            activatePortraitLayout()
        }
        applyPlayerHeightCap(containerSize: resolved, useSidebar: useSidebar)
        relatedCollectionView.backgroundColor = ThemeManager.shared.background
        let expected = useSidebar ? landscapeRelatedLayout : portraitRelatedLayout
        if relatedCollectionView.collectionViewLayout !== expected {
            relatedCollectionView.setCollectionViewLayout(expected, animated: false)
        }
        if !useSidebar { relatedCollectionView.alpha = 1 }
        view.bringSubviewToFront(playerContainer)
        view.bringSubviewToFront(sidebarContainer)
        // Do **not** call layoutIfNeeded here — nested layout during
        // viewDidLayoutSubviews multiplies main-thread work.
        if relatedCollectionView.bounds.width > 0 {
            updateRelatedLayout(isLandscape: useSidebar, containerSize: resolved)
        }
        let columnW = playerColumnWidth(
            containerSize: resolved,
            useSidebar: useSidebar
        )
        videoPlayerView?.applyResponsiveControlMetrics(forWidth: columnW)
        applyResponsiveChromeTypography(forWidth: resolved.width)
    }

    /// Scale title / channel / labels / action-bar glyphs on large windows.
    /// Skips when width bucket unchanged — every layout used to re-rasterize
    /// action icons and watchdog-killed the app (0x8BADF00D).
    func applyResponsiveChromeTypography(forWidth width: CGFloat) {
        guard width > 1 else {
            return
        }
        // Ignore sub-point jitter from layout passes.
        if abs(width - lastResponsiveChromeWidth) < 0.5,
           lastActionBarIconSize > 0 {
            return
        }
        lastResponsiveChromeWidth = width

        let titleSize = ResponsiveMetrics.chromeLabelPointSize(forWidth: width) + 5
        let bodySize = ResponsiveMetrics.chromeLabelPointSize(forWidth: width)
        let metaSize = max(12, bodySize - 1)
        titleLabel.font = UIFont.systemFont(ofSize: titleSize, weight: .semibold)
        metaLabel.font = UIFont.systemFont(ofSize: metaSize)
        channelNameLabel.font = UIFont.systemFont(ofSize: bodySize, weight: .semibold)
        channelMetaLabel.font = UIFont.systemFont(ofSize: max(11, metaSize - 1))
        commentsLabel.font = UIFont.systemFont(ofSize: bodySize, weight: .semibold)
        descriptionLabel.font = UIFont.systemFont(ofSize: metaSize)
        subscribeButton.titleLabel?.font = UIFont.systemFont(
            ofSize: bodySize,
            weight: .semibold
        )
        let caption = max(11, metaSize - 2)
        let iconSize = ResponsiveMetrics.actionBarIconSize(forWidth: width)
        let iconSizeChanged = abs(iconSize - lastActionBarIconSize) >= 0.5
        lastActionBarIconSize = iconSize

        for case let stack as UIStackView in actionBar.arrangedSubviews {
            for case let button as UIButton in stack.arrangedSubviews {
                if iconSizeChanged,
                   let name = button.accessibilityIdentifier,
                   let rendered = PlayerIcons.actionBarIcon(
                       named: name,
                       size: iconSize
                   ) {
                    button.setImage(rendered, for: .normal)
                    button.tintColor = ThemeManager.shared.primaryText
                }
                for constraint in button.constraints
                    where constraint.identifier == "actionBarIconHeight" {
                    constraint.constant = iconSize + 6
                }
            }
            for case let label as UILabel in stack.arrangedSubviews {
                label.font = UIFont.systemFont(ofSize: caption)
            }
        }
        installWatchPointerHoverIfNeeded()
    }

    private func installWatchPointerHoverIfNeeded() {
        guard ResponsiveMetrics.shouldInstallPointerHover(
            isMac: PlatformStyle.isMac
        ) else {
            return
        }
        guard !didInstallWatchPointerHover else { return }
        didInstallWatchPointerHover = true
        let buttons: [UIButton] = [
            subscribeButton,
            likeButton,
            dislikeButton,
            shareButton,
            saveButton,
            downloadButton,
            descriptionButton,
            loadMoreCommentsButton
        ]
        for button in buttons {
            if #available(iOS 13.4, *) {
                button.addInteraction(
                    UIPointerInteraction(delegate: WatchPointerRelay.shared)
                )
            }
        }
    }

    /// Cap 16:9 player height so profile/comments keep a usable region.
    /// On large Mac windows, the equal-height preferred constraint wins so
    /// the player cannot balloon and crush the metadata strip.
    func applyPlayerHeightCap(containerSize: CGSize, useSidebar: Bool) {
        let columnWidth = playerColumnWidth(
            containerSize: containerSize,
            useSidebar: useSidebar
        )
        let preferred = ResponsiveMetrics.playerHeight(
            containerWidth: columnWidth,
            containerHeight: containerSize.height
        )
        let maxH = ResponsiveMetrics.maxPlayerHeight(
            containerWidth: columnWidth,
            containerHeight: containerSize.height
        )
        guard playerAspectConstraint != nil else { return }

        // Drop aspect-ratio driver; fixed preferred height is authoritative.
        playerAspectConstraint?.isActive = false

        if playerMaxHeightConstraint == nil {
            playerMaxHeightConstraint = playerContainer.heightAnchor.constraint(
                lessThanOrEqualToConstant: maxH
            )
            playerMaxHeightConstraint?.priority = .required
            playerMaxHeightConstraint?.isActive = true
        } else {
            playerMaxHeightConstraint?.constant = maxH
        }

        if playerPrefHeightConstraint == nil {
            playerPrefHeightConstraint = playerContainer.heightAnchor.constraint(
                equalToConstant: preferred
            )
            // Required so it always beats any residual aspect constraint.
            playerPrefHeightConstraint?.priority = .required
            playerPrefHeightConstraint?.isActive = true
        } else {
            playerPrefHeightConstraint?.constant = preferred
            playerPrefHeightConstraint?.priority = .required
            if playerPrefHeightConstraint?.isActive != true {
                playerPrefHeightConstraint?.isActive = true
            }
        }
    }

    private func playerColumnWidth(
        containerSize: CGSize,
        useSidebar: Bool
    ) -> CGFloat {
        if useSidebar {
            let sidebar = sidebarWidthConstraint?.constant ?? 340
            return max(containerSize.width - sidebar, 320)
        }
        return containerSize.width
    }

    func activateLandscapeLayout() {
        scrollTrailingConstraint?.isActive = false
        scrollToSidebarConstraint?.isActive = true
        sidebarTopConstraint?.isActive = true
        sidebarTrailingConstraint?.isActive = true
        sidebarBottomConstraint?.isActive = true
        sidebarWidthConstraint?.isActive = true
        // Wider related rail on large Mac windows.
        if PlatformStyle.isMac, view.bounds.width >= 1_400 {
            sidebarWidthConstraint?.constant = 400
        } else {
            sidebarWidthConstraint?.constant = 340
        }
        sidebarContainer.isHidden = false
        playerTrailingConstraint?.isActive = false
        playerToSidebarConstraint?.isActive = true
        moveRelatedCollection(toLandscape: true)
        bottomCommentsConstraint?.isActive = true
    }

    func activatePortraitLayout() {
        bottomCommentsConstraint?.isActive = false
        scrollToSidebarConstraint?.isActive = false
        scrollTrailingConstraint?.isActive = true
        sidebarTopConstraint?.isActive = false
        sidebarTrailingConstraint?.isActive = false
        sidebarBottomConstraint?.isActive = false
        sidebarWidthConstraint?.isActive = false
        sidebarContainer.isHidden = true
        playerToSidebarConstraint?.isActive = false
        playerTrailingConstraint?.isActive = true
        moveRelatedCollection(toLandscape: false)
        metaLabel.invalidateIntrinsicContentSize()
        metaLabel.setNeedsLayout()
    }

    func updateRelatedLayout(
        isLandscape: Bool,
        containerSize: CGSize? = nil
    ) {
        let layout = isLandscape
            ? landscapeRelatedLayout
            : portraitRelatedLayout
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = isLandscape ? 0 : 6
        layout.sectionInset = UIEdgeInsets(
            top: 0, left: 8, bottom: 12, right: 8
        )
        let size = computeItemSize(
            layout: layout,
            isLandscape: isLandscape,
            containerSize: containerSize
        )
        if layout.itemSize != size {
            layout.itemSize = size
        }
        updateRelatedHeight(
            layout: layout,
            isLandscape: isLandscape,
            itemHeight: size.height
        )
        layout.invalidateLayout()
    }

    func computeItemSize(
        layout: UICollectionViewFlowLayout,
        isLandscape: Bool,
        containerSize: CGSize?
    )
        -> CGSize {
        let cols: CGFloat = isLandscape ? 1 : 2
        let inset = layout.sectionInset.left
            + layout.sectionInset.right
        let spacing = layout.minimumInteritemSpacing
            * (cols - 1)
        let baseWidth: CGFloat = if let containerSize {
            isLandscape
                ? (sidebarWidthConstraint?.constant ?? 0)
                : containerSize.width
        } else {
            relatedCollectionView.bounds.width
        }
        let available = max(baseWidth - inset - spacing, 120)
        let itemWidth = floor(available / cols)
        let itemHeight = itemWidth * (9.0 / 16.0) + 92
        return CGSize(width: itemWidth, height: itemHeight)
    }

    func updateRelatedHeight(
        layout: UICollectionViewFlowLayout,
        isLandscape: Bool,
        itemHeight: CGFloat
    ) {
        let cols: CGFloat = isLandscape ? 1 : 2
        let si = layout.sectionInset
        let headerHeight: CGFloat = isPlaylistMode ? 32 : 0
        let playlistCount = CGFloat(
            isPlaylistMode ? queue.videos.count : 0
        )
        let relatedCount = CGFloat(
            visibleRelatedVideos.count
        )
        func sectionHeight(_ count: CGFloat) -> CGFloat {
            let rows = count == 0 ? 0 : ceil(count / cols)
            return rows == 0 ? 0 : si.top + si.bottom
                + rows * itemHeight
                + max(0, rows - 1)
                * layout.minimumLineSpacing
        }
        let playlistHeight = sectionHeight(playlistCount)
        let relatedHeight = sectionHeight(relatedCount)
        let totalSections = isPlaylistMode ? 2 : 1
        let totalHeaders = CGFloat(totalSections - 1)
            * headerHeight
        let total = playlistHeight
            + relatedHeight + totalHeaders
        let desired = isLandscape ? 0 : total
        if relatedHeightConstraint?.constant != desired {
            relatedHeightConstraint?.constant = desired
        }
    }

    func moveRelatedCollection(toLandscape isLandscape: Bool) {
        guard isShowingLandscapeRelated != isLandscape else {
            return
        }
        let old = isLandscape
            ? relatedPortraitConstraints
            : relatedLandscapeConstraints
        NSLayoutConstraint.deactivate(old)
        relatedCollectionView.removeFromSuperview()
        if isLandscape {
            moveLandscapeRelated()
        } else {
            relatedCollectionView.isScrollEnabled = false
            contentView.addSubview(relatedCollectionView)
            NSLayoutConstraint.activate(relatedPortraitConstraints)
        }
        isShowingLandscapeRelated = isLandscape
    }

    private func moveLandscapeRelated() {
        relatedCollectionView.isScrollEnabled = true
        // Reset any scroll offset carried over from portrait so the first video is
        // fully visible at the top of the sidebar when entering landscape.
        relatedCollectionView.setContentOffset(.zero, animated: false)
        sidebarContainer.addSubview(relatedCollectionView)
        let rv = relatedCollectionView
        let sc = sidebarContainer
        relatedLandscapeConstraints = [
            rv.topAnchor.constraint(equalTo: sc.topAnchor),
            rv.leadingAnchor.constraint(equalTo: sc.leadingAnchor),
            rv.trailingAnchor.constraint(equalTo: sc.trailingAnchor),
            rv.bottomAnchor.constraint(equalTo: sc.bottomAnchor)
        ]
        NSLayoutConstraint.activate(relatedLandscapeConstraints)
    }
}

@available(iOS 13.4, *)
private final class WatchPointerRelay: NSObject, UIPointerInteractionDelegate {
    static let shared = WatchPointerRelay()

    func pointerInteraction(
        _ interaction: UIPointerInteraction,
        styleFor region: UIPointerRegion
    ) -> UIPointerStyle? {
        guard let view = interaction.view else { return nil }
        return UIPointerStyle(effect: .highlight(UITargetedPreview(view: view)))
    }
}
