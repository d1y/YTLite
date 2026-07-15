import UIKit

/// Applies Liquid Glass materials to primary floating chrome when available
/// (iOS 26+ / Mac Catalyst on macOS 26+). Older OS versions keep solid fills.
enum GlassChrome {
    /// Tag used to find a previously installed glass/fallback backdrop.
    static let backdropTag = 26_260_001

    /// Whether the current OS exposes glass visual effects.
    static var isGlassAvailable: Bool {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            return true
        }
        return false
    }

    /// Apply glass (or solid fallback) to a tab bar.
    static func apply(to tabBar: UITabBar, theme: ThemeManager = .shared) {
        if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()
            if #available(iOS 26.0, macCatalyst 26.0, *) {
                appearance.configureWithTransparentBackground()
            } else {
                appearance.configureWithDefaultBackground()
                appearance.backgroundColor = theme.surface.withAlphaComponent(0.92)
            }
            // Force title ink for normal + selected on every layout style —
            // missing attributes + first tab select was dropping captions
            // (icon-only tabs after first tap on iOS 26 Liquid Glass).
            applyTabItemTitleAttributes(to: appearance, theme: theme)
            tabBar.standardAppearance = appearance
            if #available(iOS 15.0, *) {
                tabBar.scrollEdgeAppearance = appearance
            }
            tabBar.isTranslucent = true
            if #available(iOS 26.0, macCatalyst 26.0, *) {
                tabBar.backgroundColor = .clear
                tabBar.barTintColor = nil
            }
        } else {
            tabBar.isTranslucent = true
            tabBar.barTintColor = theme.surface
            tabBar.backgroundColor = theme.surface
        }
        tabBar.barStyle = theme.barStyle
        tabBar.tintColor = theme.isDark ? .white : theme.accent
        tabBar.unselectedItemTintColor = theme.secondaryText
    }

    @available(iOS 13.0, *)
    private static func applyTabItemTitleAttributes(
        to appearance: UITabBarAppearance,
        theme: ThemeManager
    ) {
        let normal: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.secondaryText,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        let selected: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.isDark ? UIColor.white : theme.accent,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        let layouts = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ]
        for layout in layouts {
            layout.normal.titleTextAttributes = normal
            layout.selected.titleTextAttributes = selected
            layout.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 0)
            layout.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 0)
            // Keep icons from eating the title row.
            layout.normal.iconColor = theme.secondaryText
            layout.selected.iconColor = theme.isDark ? .white : theme.accent
        }
    }

    /// Apply glass (or solid fallback) to a navigation bar.
    static func apply(to navigationBar: UINavigationBar, theme: ThemeManager = .shared) {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.titleTextAttributes = [.foregroundColor: theme.primaryText]
            appearance.largeTitleTextAttributes = [.foregroundColor: theme.primaryText]
            navigationBar.standardAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.isTranslucent = true
            navigationBar.backgroundColor = .clear
        } else if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = theme.surface.withAlphaComponent(0.92)
            appearance.titleTextAttributes = [.foregroundColor: theme.primaryText]
            appearance.largeTitleTextAttributes = [.foregroundColor: theme.primaryText]
            navigationBar.standardAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.isTranslucent = true
        } else if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = theme.surface.withAlphaComponent(0.92)
            appearance.titleTextAttributes = [.foregroundColor: theme.primaryText]
            appearance.largeTitleTextAttributes = [.foregroundColor: theme.primaryText]
            navigationBar.standardAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.isTranslucent = true
        } else {
            navigationBar.isTranslucent = true
            navigationBar.barTintColor = theme.surface
            navigationBar.titleTextAttributes = [.foregroundColor: theme.primaryText]
        }
        navigationBar.barStyle = theme.barStyle
        navigationBar.tintColor = theme.isDark ? .white : theme.accent
    }

    /// Install a glass visual-effect backdrop behind custom chrome.
    /// Uses `UIGlassEffect` on iOS/macCatalyst 26+; solid fallback otherwise.
    /// Idempotent: replaces any prior backdrop tagged with `backdropTag`.
    @discardableResult
    static func installBackdrop(
        in container: UIView,
        cornerRadius: CGFloat = 12,
        fallbackColor: UIColor = UIColor.black.withAlphaComponent(0.55)
    ) -> UIView {
        container.viewWithTag(backdropTag)?.removeFromSuperview()

        if #available(iOS 26.0, macCatalyst 26.0, *) {
            let glassEffect = makeGlassEffect()
            let effectView = UIVisualEffectView(effect: glassEffect)
            effectView.tag = backdropTag
            // Must not steal taps from buttons sitting above the glass.
            effectView.isUserInteractionEnabled = false
            effectView.translatesAutoresizingMaskIntoConstraints = false
            effectView.clipsToBounds = true
            effectView.layer.cornerRadius = cornerRadius
            effectView.layer.cornerCurve = .continuous
            container.insertSubview(effectView, at: 0)
            NSLayoutConstraint.activate([
                effectView.topAnchor.constraint(equalTo: container.topAnchor),
                effectView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                effectView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            return effectView
        }

        let fallback = UIView()
        fallback.tag = backdropTag
        fallback.translatesAutoresizingMaskIntoConstraints = false
        fallback.backgroundColor = fallbackColor
        fallback.clipsToBounds = true
        fallback.layer.cornerRadius = cornerRadius
        container.insertSubview(fallback, at: 0)
        NSLayoutConstraint.activate([
            fallback.topAnchor.constraint(equalTo: container.topAnchor),
            fallback.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            fallback.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            fallback.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return fallback
    }

    /// Factory for the platform glass effect — extracted so tests can assert
    /// the shipped path constructs a real `UIGlassEffect`.
    @available(iOS 26.0, macCatalyst 26.0, *)
    static func makeGlassEffect(
        style: UIGlassEffect.Style = .regular,
        isInteractive: Bool = true
    ) -> UIGlassEffect {
        let glassEffect = UIGlassEffect(style: style)
        glassEffect.isInteractive = isInteractive
        return glassEffect
    }

    /// True when `view` (or a direct child) hosts a glass `UIVisualEffectView`.
    static func hostsGlassEffect(_ view: UIView) -> Bool {
        if let effectView = view as? UIVisualEffectView {
            return effectViewUsesGlass(effectView)
        }
        if let tagged = view.viewWithTag(backdropTag) as? UIVisualEffectView {
            return effectViewUsesGlass(tagged)
        }
        return view.subviews.contains { sub in
            guard let effectView = sub as? UIVisualEffectView else { return false }
            return effectViewUsesGlass(effectView)
        }
    }

    private static func effectViewUsesGlass(_ effectView: UIVisualEffectView) -> Bool {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            return effectView.effect is UIGlassEffect
        }
        return false
    }

    /// Style a floating card: installs a real `UIGlassEffect` backdrop on
    /// iOS/macCatalyst 26+, solid surface + shadow on older OS.
    @discardableResult
    static func styleFloatingCard(
        _ view: UIView,
        theme: ThemeManager = .shared
    ) -> UIView {
        if #available(iOS 13.0, *) {
            view.layer.cornerCurve = .continuous
        }
        view.layer.cornerRadius = 12

        if #available(iOS 26.0, macCatalyst 26.0, *) {
            view.clipsToBounds = true
            view.backgroundColor = .clear
            view.layer.borderWidth = 0.5
            // Edge highlight adapts: bright on dark, subtle on light.
            view.layer.borderColor = (theme.isDark
                ? UIColor.white.withAlphaComponent(0.22)
                : UIColor.black.withAlphaComponent(0.12)
            ).cgColor
            view.layer.shadowOpacity = 0
            // Live Liquid Glass material — not an alpha solid fill.
            // System glass tints from window userInterfaceStyle (see ThemeManager).
            return installBackdrop(in: view, cornerRadius: 12)
        }

        view.clipsToBounds = false
        view.backgroundColor = theme.surface
        view.layer.borderWidth = 0
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.25
        view.layer.shadowRadius = 8
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.viewWithTag(backdropTag)?.removeFromSuperview()
        return view
    }
}
