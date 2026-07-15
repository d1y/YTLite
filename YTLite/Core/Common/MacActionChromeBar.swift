import UIKit

#if targetEnvironment(macCatalyst)
import AppKit
#endif

/// macOS title-bar chrome via `NSToolbar`:
/// - Centered tab group (Home / Subscriptions / Library) using
///   `NSToolbarItemGroup` (native title-bar hits — floating UIView tabs under
///   unified titlebar do **not** reliably receive mouse events on Catalyst).
/// - Trailing search / settings / profile icons.
///
/// Note: `NSSegmentedControl` is unavailable on Mac Catalyst — do not use it.
final class MacActionChromeBar: NSObject {
    #if targetEnvironment(macCatalyst)
    private static let toolbarID = NSToolbar.Identifier("YTLite.MainActions")
    private static let tabsID = NSToolbarItem.Identifier("YTLite.tabs")
    private static let searchID = NSToolbarItem.Identifier("YTLite.search")
    private static let settingsID = NSToolbarItem.Identifier("YTLite.settings")
    private static let profileID = NSToolbarItem.Identifier("YTLite.profile")

    private weak var hostViewController: UIViewController?
    private weak var windowScene: UIWindowScene?
    private var isChromeVisible = true
    private weak var tabGroup: NSToolbarItemGroup?
    private var tabTitles: [String] = []
    private var selectedTabIndex = 0

    /// Fired when the user picks a tab in the title-bar group.
    var onTabSelect: ((Int) -> Void)?

    override private init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    @discardableResult
    static func install(
        on host: UIViewController,
        tabTitles: [String] = []
    ) -> MacActionChromeBar {
        let chrome = MacActionChromeBar()
        chrome.hostViewController = host
        chrome.tabTitles = tabTitles
        chrome.ensureAttached()
        return chrome
    }

    /// Retry-safe: toolbar install needs a live `windowScene`.
    /// Never re-attach while chrome is hidden (watch/player expanded).
    func ensureAttached() {
        guard isChromeVisible else {
            detachToolbar()
            return
        }
        attachToolbarIfNeeded()
    }

    /// Sync group selection with `UITabBarController.selectedIndex`.
    func selectTab(index: Int) {
        selectedTabIndex = index
        guard let group = tabGroup,
              index >= 0,
              index < group.subitems.count
        else {
            return
        }
        if group.selectedIndex != index {
            group.selectedIndex = index
        }
    }

    private func attachToolbarIfNeeded() {
        guard let host = hostViewController,
              let scene = host.view.window?.windowScene,
              let titlebar = scene.titlebar
        else {
            return
        }
        windowScene = scene
        if titlebar.toolbar == nil
            || titlebar.toolbar?.identifier != Self.toolbarID {
            titlebar.toolbar = makeToolbar()
        }
        if #available(macCatalyst 14.0, *) {
            titlebar.toolbarStyle = .unified
            titlebar.separatorStyle = .none
        }
        titlebar.titleVisibility = .hidden
    }

    private func makeToolbar() -> NSToolbar {
        let bar = NSToolbar(identifier: Self.toolbarID)
        bar.delegate = self
        bar.displayMode = .iconOnly
        bar.allowsUserCustomization = false
        return bar
    }

    @objc
    func applyTheme() {
        guard isChromeVisible else {
            return
        }
        rebuildToolbar()
    }

    /// Hide/show titlebar toolbar while watch panel is expanded.
    /// When hiding, always tear down toolbar — never leave tabs on-screen.
    func setVisible(_ visible: Bool) {
        isChromeVisible = visible
        if visible {
            attachToolbarIfNeeded()
            selectTab(index: selectedTabIndex)
        } else {
            detachToolbar()
        }
    }

    /// Remove title-bar tabs + actions (player expanded / shell chrome off).
    /// Always nil the titlebar toolbar — Catalyst identifier compare is unreliable
    /// and used to leave Home/Subs/Library visible on the watch surface.
    private func detachToolbar() {
        tabGroup = nil
        // Prefer host window scene; fall back to every connected scene.
        var scenes: [UIWindowScene] = []
        if let scene = windowScene
            ?? hostViewController?.view.window?.windowScene {
            windowScene = scene
            scenes.append(scene)
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            if !scenes.contains(where: { $0 === scene }) {
                scenes.append(scene)
            }
        }
        for scene in scenes {
            guard let titlebar = scene.titlebar else {
                continue
            }
            // Unconditionally clear — this app only installs our own toolbar.
            titlebar.toolbar = nil
        }
    }

    private func rebuildToolbar() {
        guard isChromeVisible else {
            detachToolbar()
            return
        }
        guard let scene = windowScene
                ?? hostViewController?.view.window?.windowScene,
              let titlebar = scene.titlebar
        else {
            return
        }
        titlebar.toolbar = makeToolbar()
        selectTab(index: selectedTabIndex)
    }

    @objc
    private func tabGroupChanged(_ sender: NSToolbarItemGroup) {
        let index = sender.selectedIndex
        guard index >= 0 else {
            return
        }
        selectedTabIndex = index
        onTabSelect?(index)
    }

    @objc
    private func searchTapped() {
        actionHost()?.toolbarOpenSearch()
    }

    @objc
    private func settingsTapped() {
        actionHost()?.toolbarOpenSettings()
    }

    @objc
    private func profileTapped() {
        actionHost()?.toolbarOpenProfile()
    }

    private func actionHost() -> UIViewController? {
        if let tab = hostViewController as? UITabBarController,
           let selected = tab.selectedViewController {
            if let nav = selected as? UINavigationController {
                return nav.topViewController ?? nav
            }
            return selected
        }
        return hostViewController
    }

    private var iconInk: UIColor {
        ThemeManager.shared.isDark
            ? .white
            : UIColor(white: 0.12, alpha: 1)
    }

    private var iconPointSize: CGFloat {
        let width = hostViewController?.view.bounds.width
            ?? UIScreen.main.bounds.width
        return ResponsiveMetrics.chromeActionIconSize(forWidth: width)
    }

    private func themedSymbol(_ systemName: String) -> UIImage? {
        let config = UIImage.SymbolConfiguration(
            pointSize: iconPointSize,
            weight: .medium
        )
        guard let symbol = UIImage(
            systemName: systemName,
            withConfiguration: config
        ) else {
            return nil
        }
        return symbol.withTintColor(iconInk, renderingMode: .alwaysOriginal)
    }

    private func makeTabsItem() -> NSToolbarItem {
        let titles = tabTitles.isEmpty
            ? ["Home", "Subscriptions", "Library"]
            : tabTitles
        // NSToolbarItemGroup is available on Catalyst; NSSegmentedControl is not.
        let group = NSToolbarItemGroup(
            itemIdentifier: Self.tabsID,
            titles: titles,
            selectionMode: .selectOne,
            labels: titles,
            target: self,
            action: #selector(tabGroupChanged(_:))
        )
        group.controlRepresentation = .expanded
        group.selectionMode = .selectOne
        group.selectedIndex = selectedTabIndex
        group.autovalidates = false
        tabGroup = group
        return group
    }

    private func makeItem(
        id: NSToolbarItem.Identifier,
        symbol: String,
        label: String,
        action: Selector
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.image = themedSymbol(symbol)
        item.isBordered = false
        item.target = self
        item.action = action
        item.autovalidates = false
        return item
    }
    #else
    var onTabSelect: ((Int) -> Void)?

    @discardableResult
    static func install(
        on host: UIViewController,
        tabTitles: [String] = []
    ) -> MacActionChromeBar {
        _ = host
        _ = tabTitles
        return MacActionChromeBar()
    }

    func ensureAttached() {}

    func selectTab(index: Int) {
        _ = index
    }

    @objc
    func applyTheme() {}

    func setVisible(_ visible: Bool) {
        _ = visible
    }
    #endif
}

#if targetEnvironment(macCatalyst)
extension MacActionChromeBar: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        // Flexible spaces center the tab group; trailing actions sit right.
        [
            .flexibleSpace,
            Self.tabsID,
            .flexibleSpace,
            Self.searchID,
            Self.settingsID,
            Self.profileID
        ]
    }

    func toolbarAllowedItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case Self.tabsID:
            return makeTabsItem()
        case Self.searchID:
            return makeItem(
                id: itemIdentifier,
                symbol: "magnifyingglass",
                label: "Search",
                action: #selector(searchTapped)
            )
        case Self.settingsID:
            return makeItem(
                id: itemIdentifier,
                symbol: "gearshape",
                label: "Settings",
                action: #selector(settingsTapped)
            )
        case Self.profileID:
            return makeItem(
                id: itemIdentifier,
                symbol: "person.crop.circle",
                label: "Profile",
                action: #selector(profileTapped)
            )
        default:
            return nil
        }
    }
}
#endif
