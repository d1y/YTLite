import UIKit

class MainTabBarController: UITabBarController {
    private let dependencies: AppDependencies
    private weak var playerPanel: PlayerPanelViewController?
    private var miniPlayerBar: MiniPlayerBar?
    private var miniPlayerBarBottomConstraint: NSLayoutConstraint?
    /// macOS title-bar: centered tabs + trailing search/settings/profile.
    private var macActionChrome: MacActionChromeBar?
    private var shellChromeHidden = false

    override var childForStatusBarHidden: UIViewController? {
        playerPanel ?? selectedViewController
    }

    override var childForStatusBarStyle: UIViewController? {
        playerPanel ?? selectedViewController
    }

    override var childForHomeIndicatorAutoHidden: UIViewController? {
        playerPanel ?? selectedViewController
    }

    override var shouldAutorotate: Bool {
        if UIDevice.current.userInterfaceIdiom != .pad {
            return false
        }
        return selectedViewController?.shouldAutorotate ?? super.shouldAutorotate
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom != .pad {
            return .portrait
        }
        return selectedViewController?.supportedInterfaceOrientations
            ?? super.supportedInterfaceOrientations
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
        ToolbarManager.shared.searchViewControllerFactory = { [dependencies] in
            dependencies.makeSearchViewController()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        viewControllers = buildTabs()
        configurePlatformChrome()
        stripMacNavBarChrome()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: .appLanguageDidChange,
            object: nil
        )
        applyTheme()
        if !PlatformStyle.isMac {
            refreshTabBarTitles()
        }
    }

    @objc
    private func handleLanguageChange() {
        refreshTabBarTitles()
        if PlatformStyle.isMac {
            // Rebuild title-bar chrome with localized tab titles.
            macActionChrome?.setVisible(false)
            macActionChrome = nil
            if !shellChromeHidden {
                installMacChromeIfNeeded()
            }
        }
        applyTheme()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configurePlatformChrome()
        stripMacNavBarChrome()
        // iOS Liquid Glass can drop unselected captions after chrome toggles.
        if !PlatformStyle.isMac {
            refreshTabBarTitles()
        }
        // Player expanded → hide Mac title-bar tabs (must not re-install first).
        let shellVisible = ResponsiveMetrics.shellChromeVisible(
            playerExpanded: playerPanel?.isExpanded == true
        )
        applyShellChromeVisibility(visible: shellVisible)
        if shellVisible {
            installMacChromeIfNeeded()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if PlatformStyle.isMac {
            if shellChromeHidden || playerPanel?.isExpanded == true {
                // Hard rule: expanded watch → no title-bar tabs.
                shellChromeHidden = true
                macActionChrome?.setVisible(false)
            } else {
                macActionChrome?.ensureAttached()
            }
            if let mini = miniPlayerBar, !mini.isHidden {
                view.bringSubviewToFront(mini)
            }
        }
    }

    // MARK: - Platform chrome

    private func configurePlatformChrome() {
        if PlatformStyle.isMac {
            // System tab bar on Catalyst does not reliably render as a
            // top-centered control — title-bar NSSegmentedControl owns tabs.
            if #available(iOS 18.0, *) {
                mode = .tabBar
                sidebar.isHidden = true
            }
            tabBar.isHidden = ResponsiveMetrics.systemTabBarHidden(
                isMac: true,
                shellChromeHidden: shellChromeHidden
            )
        } else {
            // iOS keeps native UITabBarController liquid-glass behavior.
            if #available(iOS 18.0, *) {
                mode = .tabBar
            }
            // Honor shellChromeHidden — never force-show the tab bar while
            // the expanded player owns the surface (theme/apply reconfigure).
            tabBar.isHidden = ResponsiveMetrics.systemTabBarHidden(
                isMac: false,
                shellChromeHidden: shellChromeHidden
            )
        }
    }

    private func installMacChromeIfNeeded() {
        guard PlatformStyle.prefersMacTitlebarActions else { return }
        // Watch expanded owns the window — never re-show title-bar tabs.
        if shellChromeHidden {
            macActionChrome?.setVisible(false)
            return
        }
        if macActionChrome == nil {
            let titles = [
                L10n.tr(L10n.Tab.home),
                L10n.tr(L10n.Tab.subscriptions),
                L10n.tr(L10n.Tab.library)
            ]
            let chrome = MacActionChromeBar.install(on: self, tabTitles: titles)
            chrome.onTabSelect = { [weak self] index in
                self?.selectMacTab(index: index)
            }
            macActionChrome = chrome
        } else {
            macActionChrome?.ensureAttached()
        }
        macActionChrome?.setVisible(true)
        macActionChrome?.selectTab(index: selectedIndex)
    }

    /// Switch root tab from title-bar segment (or any Mac chrome).
    func selectMacTab(index: Int) {
        guard let vcs = viewControllers, vcs.indices.contains(index) else {
            return
        }
        if selectedIndex != index {
            selectedIndex = index
        }
        // Force selection even if system UITabBar is hidden (Catalyst).
        selectedViewController = vcs[index]
        macActionChrome?.selectTab(index: index)
        stripMacNavBarChrome()
    }

    /// Show/hide feed-shell chrome (tabs + Mac titlebar actions).
    /// When player is expanded, Mac title-bar tabs **must** stay gone.
    func applyShellChromeVisibility(visible: Bool) {
        shellChromeHidden = !visible
        tabBar.isHidden = ResponsiveMetrics.systemTabBarHidden(
            isMac: PlatformStyle.isMac,
            shellChromeHidden: shellChromeHidden
        )
        if PlatformStyle.isMac {
            // Never invent multi-dozen-pt feed gap under title-bar tabs.
            additionalSafeAreaInsets.top = ResponsiveMetrics.macRootFeedTopExtraInset()
            if visible {
                installMacChromeIfNeeded()
            } else {
                // Force-hide first; do not call install while hidden.
                macActionChrome?.setVisible(false)
            }
        } else {
            additionalSafeAreaInsets.top = 0
        }
    }

    /// On Mac, root feed chrome lives in the title bar —
    /// strip nav right items and blank root titles so "Home" is not a
    /// second, off-center label under the real tabs.
    /// Also **force-hide** empty root nav bars (kills the black band under
    /// the unified title bar — Image #1 gap).
    private func stripMacNavBarChrome() {
        guard PlatformStyle.prefersMacTitlebarActions else { return }
        viewControllers?.forEach { root in
            if let nav = root as? UINavigationController {
                nav.navigationBar.prefersLargeTitles = false
                // Hide empty root nav bars — eliminates the large black band
                // between title-bar tabs and the feed (Image #1).
                if nav.viewControllers.count <= 1 {
                    nav.setNavigationBarHidden(true, animated: false)
                    nav.navigationBar.isHidden = true
                }
                for (index, vc) in nav.viewControllers.enumerated() {
                    vc.navigationItem.rightBarButtonItems = nil
                    vc.navigationItem.rightBarButtonItem = nil
                    vc.navigationItem.largeTitleDisplayMode = .never
                    if index == 0 {
                        // Hide nav title only — never clear `vc.title` (wipes tab caption).
                        vc.navigationItem.title = ""
                    }
                }
            } else {
                root.navigationItem.rightBarButtonItems = nil
                root.navigationItem.rightBarButtonItem = nil
                root.navigationItem.title = ""
            }
        }
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *),
           traitCollection.hasDifferentColorAppearance(
               comparedTo: previousTraitCollection
           ) {
            ThemeManager.shared.refreshAutoTheme()
        }
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(
            alongsideTransition: { [weak self] _ in
                self?.tabBar.setNeedsLayout()
                if self?.shellChromeHidden != true {
                    self?.macActionChrome?.applyTheme()
                }
            },
            completion: { [weak self] _ in
                self?.tabBar.setNeedsLayout()
                self?.tabBar.layoutIfNeeded()
            }
        )
    }

    private func buildTabs() -> [UIViewController] {
        [makeHomeTab(), makeSubscriptionsTab(), makeLibraryTab()]
    }

    private func makeHomeTab() -> UIViewController {
        let home = RotatingNavigationController(
            rootViewController: HomeViewController(
                service: dependencies.feedService,
                channelViewControllerFactory:
                    dependencies.makeChannelViewController
            )
        )
        // Titles on the **nav** tab root only — never drive tab labels via child VC.title
        // (clearing child title used to blank unselected tab captions intermittently).
        applyTabBarItem(
            to: home,
            titleKey: L10n.Tab.home,
            image: TabBarIcons.home(),
            tag: 0
        )
        return home
    }

    private func makeSubscriptionsTab() -> UIViewController {
        let subs = RotatingNavigationController(
            rootViewController:
                dependencies.makeSubscriptionsViewController()
        )
        applyTabBarItem(
            to: subs,
            titleKey: L10n.Tab.subscriptions,
            image: TabBarIcons.subscriptions(),
            tag: 1
        )
        return subs
    }

    private func makeLibraryTab() -> UIViewController {
        let library = RotatingNavigationController(
            rootViewController: LibraryViewController(
                dependencies: dependencies
            )
        )
        applyTabBarItem(
            to: library,
            titleKey: L10n.Tab.library,
            image: TabBarIcons.library(),
            tag: 2
        )
        return library
    }

    /// Always set title + image + selectedImage so Liquid Glass tab bar
    /// never drops captions on unselected items.
    ///
    /// **Do not** assign `controller.title = ""` after setting `tabBarItem` —
    /// UIViewController.title syncs into tabBarItem.title and blanks captions
    /// (that caused “only one tab shows text”).
    private func applyTabBarItem(
        to controller: UIViewController,
        titleKey: String,
        image: UIImage?,
        tag: Int
    ) {
        let title = L10n.tr(titleKey)
        let item = UITabBarItem(title: title, image: image, tag: tag)
        item.selectedImage = image
        item.imageInsets = .zero
        item.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 0)
        controller.tabBarItem = item
        // Re-assert title after assignment (defensive against any title sync).
        controller.tabBarItem.title = title
        controller.tabBarItem.image = image
        controller.tabBarItem.selectedImage = image
    }

    /// Re-assert all three tab titles (language change + appear).
    private func refreshTabBarTitles() {
        guard let vcs = viewControllers, vcs.count >= 3 else {
            return
        }
        let keys = [L10n.Tab.home, L10n.Tab.subscriptions, L10n.Tab.library]
        let images = [TabBarIcons.home(), TabBarIcons.subscriptions(), TabBarIcons.library()]
        for index in 0..<3 {
            applyTabBarItem(
                to: vcs[index],
                titleKey: keys[index],
                image: images[index],
                tag: index
            )
        }
    }

    @objc
    private func applyTheme() {
        configurePlatformChrome()
        GlassChrome.apply(to: tabBar)
        ThemeManager.shared.applyInterfaceStyleToWindows()
        if !shellChromeHidden {
            macActionChrome?.applyTheme()
        }
        miniPlayerBar?.applyTheme()
        stripMacNavBarChrome()
    }

    // MARK: - Player panel

    func installPlayerPanel(_ panel: PlayerPanelViewController) {
        if let existing = playerPanel {
            removePlayerPanel(existing)
        }
        addChild(panel)
        panel.view.frame = view.bounds
        panel.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(panel.view, aboveSubview: tabBar)
        panel.didMove(toParent: self)
        playerPanel = panel

        miniPlayerBar?.removeFromSuperview()
        let bar = MiniPlayerBar()
        view.addSubview(bar)
        let bottomConstraint = bar.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -12
        )
        // Mini player sits bottom-trailing on both platforms (Mac previously
        // centered — wrong; keep it on the right like YouTube desktop).
        let widthMultiplier: CGFloat = PlatformStyle.isMac ? 0.26 : (1.0 / 3.0)
        NSLayoutConstraint.activate([
            bar.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),
            bar.widthAnchor.constraint(
                equalTo: view.widthAnchor,
                multiplier: widthMultiplier
            ),
            bottomConstraint
        ])
        bar.isHidden = true
        bar.alpha = 0
        miniPlayerBar = bar
        miniPlayerBarBottomConstraint = bottomConstraint

        panel.miniBar = bar
        panel.onExpandedChange = { [weak self] expanded in
            self?.applyShellChromeVisibility(
                visible: ResponsiveMetrics.shellChromeVisible(
                    playerExpanded: expanded
                )
            )
        }
        panel.view.transform = CGAffineTransform(
            translationX: 0, y: view.bounds.height
        )
        // Hide shell while expanded player owns the surface.
        applyShellChromeVisibility(visible: false)
        panel.expand(animated: true)
        // Re-assert hide after expand + one layout cycle (windowScene / titlebar
        // may not be ready on the first call; tabs used to stick on watch).
        DispatchQueue.main.async { [weak self] in
            self?.applyShellChromeVisibility(visible: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard self?.playerPanel?.isExpanded == true else {
                return
            }
            self?.applyShellChromeVisibility(visible: false)
        }
    }

    func removePlayerPanel(_ panel: PlayerPanelViewController) {
        if playerPanel === panel {
            playerPanel = nil
        }
        miniPlayerBar?.removeFromSuperview()
        miniPlayerBar = nil
        miniPlayerBarBottomConstraint = nil
        panel.willMove(toParent: nil)
        panel.view.removeFromSuperview()
        panel.removeFromParent()
        applyShellChromeVisibility(visible: true)
        DispatchQueue.main.async { [weak self] in
            self?.tabBar.setNeedsLayout()
            self?.tabBar.layoutIfNeeded()
            self?.stripMacNavBarChrome()
        }
    }

    override var selectedIndex: Int {
        didSet {
            macActionChrome?.selectTab(index: selectedIndex)
            // iOS: re-pin captions after every tab change (UIKit may copy
            // empty topVC.title into tabBarItem on first select).
            if !PlatformStyle.isMac {
                refreshTabBarTitles()
            }
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension MainTabBarController: UITabBarControllerDelegate {
    func tabBarController(
        _ tabBarController: UITabBarController,
        didSelect viewController: UIViewController
    ) {
        guard !PlatformStyle.isMac else {
            return
        }
        refreshTabBarTitles()
    }
}
