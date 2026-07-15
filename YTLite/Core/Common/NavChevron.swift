import UIKit

/// The single factory for navigation chevrons. Every screen builds its
/// back/minimize button here — and `RotatingNavigationController` replaces
/// the system back button on push — so the glyph and edge inset are
/// identical on every screen and iOS version.
enum NavChevron {
    enum Kind {
        case back
        case minimize
    }

    /// Chevron glyph tint that tracks app light/dark theme (not hard-coded white).
    static func glyphTint(theme: ThemeManager = .shared) -> UIColor {
        theme.primaryText
    }

    /// Shared side length for Mac floating back (search / watch) — matches
    /// the playlist `NavChevronButton` visual weight.
    static var macFloatingSide: CGFloat {
        ResponsiveMetrics.macSearchControlHeight()
    }

    /// Soft circular fill for floating Mac backs (not opaque black, not double glass).
    static func macFloatingFill(theme: ThemeManager = .shared) -> UIColor {
        ResponsiveMetrics.macSearchBackFill(isDark: theme.isDark)
    }

    static func barButton(
        kind: Kind,
        target: Any?,
        action: Selector
    ) -> UIBarButtonItem {
        UIBarButtonItem(
            customView: NavChevronButton(kind: kind, target: target, action: action)
        )
    }

    static func image(kind: Kind) -> UIImage? {
        if #available(iOS 13.0, *) {
            let name = kind == .back ? "chevron.left" : "chevron.down"
            // Slightly smaller than old 21pt so the glyph sits cleanly inside
            // the iOS 26 liquid-glass circle without optical offset.
            let cfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            return UIImage(systemName: name, withConfiguration: cfg)?
                .withRenderingMode(.alwaysTemplate)
        }
        return drawnChevron(kind: kind)
    }

    /// Style a floating Mac back/close `UIButton` like the playlist nav chevron:
    /// same SF Symbol weight, theme glyph tint, soft circular fill (single layer).
    static func applyMacFloatingStyle(
        to button: UIButton,
        kind: Kind = .back,
        theme: ThemeManager = .shared,
        side: CGFloat? = nil
    ) {
        let diameter = side ?? macFloatingSide
        let glyph = image(kind: kind)?.withRenderingMode(.alwaysTemplate)
        button.setImage(glyph, for: .normal)
        button.tintColor = glyphTint(theme: theme)
        button.backgroundColor = macFloatingFill(theme: theme)
        button.layer.cornerRadius = diameter / 2
        button.clipsToBounds = true
        if #available(iOS 13.0, *) {
            button.layer.cornerCurve = .circular
        }
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.imageView?.contentMode = .scaleAspectFit
        button.contentEdgeInsets = .zero
        button.imageEdgeInsets = .zero
    }

    // MARK: - Pre-iOS 13 fallback (no SF Symbols)

    private static func drawnChevron(kind: Kind) -> UIImage {
        let size: CGSize
        let points: [CGPoint]
        switch kind {
        case .back:
            size = CGSize(width: 13, height: 22)
            points = [
                CGPoint(x: 11, y: 2),
                CGPoint(x: 2, y: 11),
                CGPoint(x: 11, y: 20)
            ]
        case .minimize:
            size = CGSize(width: 22, height: 13)
            points = [
                CGPoint(x: 2, y: 2),
                CGPoint(x: 11, y: 11),
                CGPoint(x: 20, y: 2)
            ]
        }
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            let path = UIBezierPath()
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.lineWidth = 3
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.black.setStroke()
            path.stroke()
        }
        // Template so the navigation bar tint colors it per theme.
        return image.withRenderingMode(.alwaysTemplate)
    }
}

/// Self-aligning chevron bar button. UIKit positions bar items at
/// context-dependent offsets (root vs pushed slot, tab vs child-embedded
/// bar, glass vs legacy metrics — measured 12.5pt vs 31pt for the same
/// button), so after layout the view checks where the bar actually put it
/// and shifts itself to sit exactly `edgeInset` from the screen edge.
final class NavChevronButton: UIView {
    /// Match iOS 26 liquid-glass circle (~36pt), not oversized 44pt hit box.
    private static let side: CGFloat = 36

    private let button = UIButton(type: .system)
    private let kind: NavChevron.Kind

    override var intrinsicContentSize: CGSize {
        CGSize(width: Self.side, height: Self.side)
    }

    init(kind: NavChevron.Kind, target: Any?, action: Selector) {
        self.kind = kind
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        let image = NavChevron.image(kind: kind)?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        // Geometric center inside the glass pill — never leading/edge transform.
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.imageView?.contentMode = .scaleAspectFit
        // SF `chevron.left` optical mass sits left of its box; nudge so it
        // reads centered in the circle (watch was too far right, search too left
        // when we used a wide 44pt host + edge transform).
        if kind == .back {
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0.5, bottom: 0, right: -0.5)
        } else {
            button.imageEdgeInsets = .zero
        }
        button.addTarget(target, action: action, for: .touchUpInside)
        button.frame = bounds
        button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        isUserInteractionEnabled = true
        button.isUserInteractionEnabled = true
        addSubview(button)
        accessibilityTraits = .button
        accessibilityLabel = kind == .back ? "Back" : "Close"
        backgroundColor = .clear
        isOpaque = false
        // Never translate this view — Liquid Glass wraps the bar item; a
        // transform shifts only the glyph and looks off-center in the pill.
        transform = .identity
        applyTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
        if PlatformStyle.isMac {
            MacPointerHover.install(on: button)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(
                comparedTo: previousTraitCollection
            ) {
                ThemeManager.shared.refreshAutoTheme()
                applyTheme()
            }
        }
    }

    @objc
    func applyTheme() {
        button.tintColor = NavChevron.glyphTint()
        button.backgroundColor = .clear
        backgroundColor = .clear
        transform = .identity
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        transform = .identity
        button.frame = bounds
        // Keep image centered after bar re-layout.
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyTheme()
        transform = .identity
    }

    /// Kept for RotatingNavigationController transition callbacks.
    func realign() {
        transform = .identity
        setNeedsLayout()
    }
}
