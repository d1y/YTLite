import UIKit

/// The app-wide navigation controller: forwards rotation queries to the top
/// view controller and replaces the system back button on push with the
/// shared `NavChevron` button, so the chevron looks and sits the same on
/// every screen and iOS version.
final class RotatingNavigationController: UINavigationController {
    override var shouldAutorotate: Bool {
        topViewController?.shouldAutorotate ?? super.shouldAutorotate
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        topViewController?.supportedInterfaceOrientations
            ?? super.supportedInterfaceOrientations
    }
    override var prefersStatusBarHidden: Bool {
        topViewController?.prefersStatusBarHidden ?? super.prefersStatusBarHidden
    }
    override var childForStatusBarHidden: UIViewController? {
        topViewController
    }
    override var prefersHomeIndicatorAutoHidden: Bool {
        topViewController?.prefersHomeIndicatorAutoHidden ?? super.prefersHomeIndicatorAutoHidden
    }
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        topViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Replacing the system back button disables the edge-swipe pop
        // gesture; re-enable it (guarded so the root screen never pops).
        interactivePopGestureRecognizer?.delegate = self
        delegate = self
        applyBarTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyBarTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    /// One bar configuration for every navigation bar in the app — bars
    /// with differing appearance setups use different item-layout metrics
    /// (visibly different chevron insets), so the bar styles itself here
    /// instead of per screen. Uses Liquid Glass when available.
    @objc
    private func applyBarTheme() {
        GlassChrome.apply(to: navigationBar)
    }

    override func pushViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) {
        // `topViewController == nil` means this is the root being installed —
        // it gets no back button. Screens that manage their own left item
        // (e.g. the watch screen) are left alone.
        // Mac Search owns a custom circular back — do not inject NavChevron.
        let isMacSearch = PlatformStyle.isMac
            && viewController is SearchViewController
        if topViewController != nil,
           viewController.navigationItem.leftBarButtonItem == nil,
           !isMacSearch {
            viewController.navigationItem.hidesBackButton = true
            viewController.navigationItem.leftBarButtonItem = NavChevron.barButton(
                kind: .back,
                target: self,
                action: #selector(popTapped)
            )
        }
        if isMacSearch {
            viewController.navigationItem.hidesBackButton = true
            viewController.navigationItem.leftBarButtonItem = nil
        }
        super.pushViewController(viewController, animated: animated)
    }

    @objc
    private func popTapped() {
        popViewController(animated: true)
    }
}

extension RotatingNavigationController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

// MARK: - Chevron realignment after transitions

// The chevron aligns itself to the screen edge in layoutSubviews, but a
// layout pass that runs mid-push measures the slot's in-flight position and
// bakes in a wrong shift. Re-align once the transition settles (covering a
// cancelled interactive pop, where `didShow` never fires for the target).
extension RotatingNavigationController: UINavigationControllerDelegate {
    private static func realignChevron(of viewController: UIViewController?) {
        let item = viewController?.navigationItem.leftBarButtonItem
        guard let chevron = item?.customView as? NavChevronButton else {
            return
        }
        chevron.realign()
        // The bar can move the item's wrapper once more within the same
        // layout pass (invisible to the view's own overrides); one more
        // pass on the next tick catches it.
        DispatchQueue.main.async { [weak chevron] in
            chevron?.realign()
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        // Mac: hide empty root nav bars (kills huge black band under title
        // tabs) and hide bar on Search (custom chrome). Show for pushes.
        // Modal sheets (Settings) and Watch (back/minimize) always keep the bar.
        if PlatformStyle.isMac {
            let isRoot = navigationController.viewControllers.first
                === viewController
            let isSearch = viewController is SearchViewController
            let isWatch = viewController is WatchViewController
            let isModal = navigationController.presentingViewController != nil
            let hide = ResponsiveMetrics.macNavigationBarHidden(
                isRoot: isRoot,
                isSearchScreen: isSearch,
                isPresentedModally: isModal,
                isWatchScreen: isWatch
            )
            navigationController.setNavigationBarHidden(hide, animated: animated)
            if !hide {
                navigationController.navigationBar.isHidden = false
                GlassChrome.apply(to: navigationController.navigationBar)
            }
        }
        Self.realignChevron(of: viewController)
        guard let coordinator = navigationController.transitionCoordinator else {
            return
        }
        // Inside the animation block, so if the slot moved after the first
        // measurement the chevron glides into place with the push instead
        // of visibly jumping after it.
        coordinator.animate(
            alongsideTransition: { _ in
                Self.realignChevron(of: viewController)
            },
            completion: { context in
                let shown = context.isCancelled
                    ? navigationController.topViewController
                    : viewController
                Self.realignChevron(of: shown)
            }
        )
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        Self.realignChevron(of: viewController)
    }
}
