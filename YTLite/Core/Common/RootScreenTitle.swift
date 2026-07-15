import UIKit

/// Root feed chrome titles.
/// Home / Subscriptions: **no** in-content nav title (tabs already name the screen).
///
/// Important: never leave `viewController.title` empty on iOS tab children —
/// UIKit can copy topVC.title into the tab's `tabBarItem.title` on first select
/// and wipe captions (only icons left). Keep the tab label on `.title`, hide
/// it from the nav bar via `navigationItem.title = ""`.
enum RootScreenTitle {
    /// Hide nav title chrome. Optionally keep a non-empty `title` for tab sync.
    static func clear(on viewController: UIViewController, tabTitle: String? = nil) {
        if let tabTitle, !tabTitle.isEmpty {
            // Non-empty title prevents tabBarItem wipe; nav bar uses navigationItem.
            viewController.title = tabTitle
        }
        viewController.navigationItem.title = ""
        // Only strip a title *label* we installed — never a back chevron.
        if viewController.navigationItem.leftBarButtonItem?.customView is UILabel {
            viewController.navigationItem.leftBarButtonItem = nil
        }
    }

    static func apply(to viewController: UIViewController, text: String) {
        clear(on: viewController, tabTitle: text.isEmpty ? nil : text)
    }

    static func updateLabel(in viewController: UIViewController, text: String) {
        clear(on: viewController, tabTitle: text.isEmpty ? nil : text)
    }
}
