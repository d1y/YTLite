import UIKit

/// Top-centered Liquid Glass tab strip for macOS (Home / Subscriptions / Library).
/// System UITabBar on Catalyst often fails to appear top-centered; this is the
/// reliable chrome matching the macOS design language.
final class MacTopTabBar: UIView {
    private let stack = UIStackView()
    private var buttons: [UIButton] = []
    private var selectedIndex = 0
    var onSelect: ((Int) -> Void)?

    private let titles: [String]

    init(titles: [String]) {
        self.titles = titles
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup()
        applyTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setup() {
        isUserInteractionEnabled = true
        GlassChrome.styleFloatingCard(self)
        layer.cornerRadius = 22
        if #available(iOS 13.0, *) {
            layer.cornerCurve = .continuous
        }

        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.isUserInteractionEnabled = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for (index, title) in titles.enumerated() {
            let button = makeTabButton(title: title, index: index)
            buttons.append(button)
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            heightAnchor.constraint(equalToConstant: 42)
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        updateSelectionAppearance()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 42)
    }

    private func makeTabButton(title: String, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.layer.cornerRadius = 17
        if #available(iOS 13.0, *) {
            button.layer.cornerCurve = .continuous
        }
        button.contentEdgeInsets = UIEdgeInsets(top: 7, left: 18, bottom: 7, right: 18)
        button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        MotionStyle.installPressFeedback(on: button)
        // Always enable interaction; parent hitTest routes events here.
        button.isUserInteractionEnabled = true
        if ResponsiveMetrics.shouldInstallPointerHover(isMac: PlatformStyle.isMac) {
            installHover(on: button)
            MacPointerHover.install(on: button)
        }
        return button
    }

    private func installHover(on button: UIButton) {
        if #available(iOS 13.4, *) {
            button.addInteraction(UIPointerInteraction(delegate: TabPointerDelegate.shared))
        }
        if #available(iOS 13.0, *) {
            installHoverGesture(on: button)
        }
    }

    @available(iOS 13.0, *)
    private func installHoverGesture(on button: UIButton) {
        let hover = UIHoverGestureRecognizer(
            target: self,
            action: #selector(handleHover(_:))
        )
        button.addGestureRecognizer(hover)
    }

    @available(iOS 13.0, *)
    @objc
    private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        guard let button = gesture.view as? UIButton else { return }
        let selected = button.tag == selectedIndex
        switch gesture.state {
        case .began, .changed:
            if !selected {
                button.backgroundColor = ThemeManager.shared.primaryText
                    .withAlphaComponent(0.08)
            }
        case .ended, .cancelled:
            if !selected {
                button.backgroundColor = .clear
            }
        default:
            break
        }
    }

    @objc
    private func tabTapped(_ sender: UIButton) {
        select(index: sender.tag, notify: true)
    }

    func select(index: Int, notify: Bool) {
        guard titles.indices.contains(index) else { return }
        selectedIndex = index
        updateSelectionAppearance()
        if notify {
            onSelect?(index)
        }
    }

    func updateTitlesFont(forWidth width: CGFloat) {
        // Base 15pt, scale up on large Mac windows (never phone-tiny).
        let size = max(15, ResponsiveMetrics.chromeLabelPointSize(forWidth: width))
        buttons.forEach {
            $0.titleLabel?.font = UIFont.systemFont(ofSize: size, weight: .semibold)
        }
    }

    @objc
    func applyTheme() {
        GlassChrome.styleFloatingCard(self)
        layer.cornerRadius = 22
        updateSelectionAppearance()
    }

    private func updateSelectionAppearance() {
        let theme = ThemeManager.shared
        for button in buttons {
            let selected = button.tag == selectedIndex
            if selected {
                button.backgroundColor = theme.isDark
                    ? UIColor.white.withAlphaComponent(0.18)
                    : UIColor.black.withAlphaComponent(0.08)
                button.setTitleColor(theme.primaryText, for: .normal)
            } else {
                button.backgroundColor = .clear
                button.setTitleColor(theme.secondaryText, for: .normal)
            }
        }
    }
}

@available(iOS 13.4, *)
private final class TabPointerDelegate: NSObject, UIPointerInteractionDelegate {
    static let shared = TabPointerDelegate()

    func pointerInteraction(
        _ interaction: UIPointerInteraction,
        styleFor region: UIPointerRegion
    ) -> UIPointerStyle? {
        guard let view = interaction.view else { return nil }
        return UIPointerStyle(effect: .highlight(UITargetedPreview(view: view)))
    }
}
