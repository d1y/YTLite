import UIKit

/// Full-width, pass-through top strip for macOS tab chrome.
///
/// - Hosts the centered `MacTopTabBar` pill.
/// - `hitTest` returns `nil` outside the pill so feed cells receive clicks.
/// - Always sits above full-bleed child VCs so Subscriptions / Library work.
final class MacTopTabStrip: UIView {
    let tabBar: MacTopTabBar

    var onSelect: ((Int) -> Void)? {
        get { tabBar.onSelect }
        set { tabBar.onSelect = newValue }
    }

    init(titles: [String]) {
        tabBar = MacTopTabBar(titles: titles)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
        backgroundColor = .clear
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setup() {
        addSubview(tabBar)
        let height = ResponsiveMetrics.macTopTabStripHeight()
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),
            tabBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            tabBar.centerYAnchor.constraint(equalTo: centerYAnchor),
            tabBar.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
            tabBar.widthAnchor.constraint(
                lessThanOrEqualTo: widthAnchor,
                multiplier: 0.55
            )
        ])
        MacPointerHover.install(on: tabBar)
    }

    func select(index: Int, notify: Bool) {
        tabBar.select(index: index, notify: notify)
    }

    func updateTitlesFont(forWidth width: CGFloat) {
        tabBar.updateTitlesFont(forWidth: width)
    }

    func applyTheme() {
        tabBar.applyTheme()
    }

    /// Only the glass pill captures hits; empty strip area is transparent
    /// so feed cells underneath still receive clicks (no UIView swizzle).
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled else {
            return nil
        }
        // Point is in strip coordinates.
        let barPoint = convert(point, to: tabBar)
        let inside = tabBar.point(inside: barPoint, with: event)
        guard ResponsiveMetrics.macTopTabHitTakesPriority(
            pointInsideTabControl: inside,
            shellChromeHidden: false
        ) else {
            // Pass through — do not claim the hit.
            return nil
        }
        // Dispatch into the pill (uses normal UIView.hitTest — never swizzled).
        return tabBar.hitTest(barPoint, with: event)
    }

    /// Pure geometry helper for tests: which tab index contains a point
    /// in strip coordinates (or nil if outside the pill).
    func tabIndex(atStripPoint point: CGPoint) -> Int? {
        let barPoint = convert(point, to: tabBar)
        guard tabBar.point(inside: barPoint, with: nil) else { return nil }
        for sub in tabBar.subviews {
            // Stack holds the tab buttons.
            if let stack = sub as? UIStackView {
                for case let button as UIButton in stack.arrangedSubviews {
                    let p = tabBar.convert(barPoint, to: button)
                    if button.point(inside: p, with: nil) {
                        return button.tag
                    }
                }
            }
        }
        return nil
    }
}
