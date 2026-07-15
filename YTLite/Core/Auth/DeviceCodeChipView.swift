import UIKit

/// Desktop-friendly device code pill: hover highlight, press scale, tap-to-copy feedback.
final class DeviceCodeChipView: UIControl {
    private let codeLabel = UILabel()
    private let hintLabel = UILabel()
    private let stack = UIStackView()

    private let normalBackground = UIColor(white: 0.14, alpha: 1)
    private let hoverBackground = UIColor(white: 0.22, alpha: 1)
    private let pressedBackground = UIColor(white: 0.28, alpha: 1)
    private let successBackground = UIColor(red: 0.15, green: 0.45, blue: 0.25, alpha: 1)

    private var isPointerInside = false
    private var feedbackResetWork: DispatchWorkItem?

    var code: String? {
        get { codeLabel.text }
        set {
            codeLabel.text = newValue
            isHidden = (newValue == nil || newValue?.isEmpty == true)
            resetChrome(animated: false)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "Copies the sign-in code"
        setup()
        installPointerChrome()
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        MotionStyle.installPressFeedback(on: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setup() {
        backgroundColor = normalBackground
        layer.cornerRadius = 14
        if #available(iOS 13.0, *) {
            layer.cornerCurve = .continuous
        }
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        clipsToBounds = true

        codeLabel.font = UIFont(name: "Menlo-Bold", size: 32)
            ?? UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        codeLabel.textColor = .white
        codeLabel.textAlignment = .center
        codeLabel.adjustsFontSizeToFitWidth = true
        codeLabel.minimumScaleFactor = 0.6

        hintLabel.text = "Click to copy"
        hintLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.45)
        hintLabel.textAlignment = .center

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(codeLabel)
        stack.addArrangedSubview(hintLabel)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 88),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 280)
        ])

        isHidden = true
    }

    private func installPointerChrome() {
        if #available(iOS 13.4, *) {
            addInteraction(UIPointerInteraction(delegate: self))
        }
        if #available(iOS 13.0, *) {
            installHoverGesture()
        }
    }

    @available(iOS 13.0, *)
    private func installHoverGesture() {
        let hover = UIHoverGestureRecognizer(
            target: self,
            action: #selector(handleHover(_:))
        )
        addGestureRecognizer(hover)
    }

    @available(iOS 13.0, *)
    @objc
    private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            guard !isPointerInside else { return }
            isPointerInside = true
            applyHover(true)
        case .ended, .cancelled:
            isPointerInside = false
            applyHover(false)
        default:
            break
        }
    }

    private func applyHover(_ hovering: Bool) {
        guard feedbackResetWork == nil else { return }
        MotionStyle.animateChrome(duration: 0.16) {
            self.backgroundColor = hovering ? self.hoverBackground : self.normalBackground
            self.layer.borderColor = UIColor.white
                .withAlphaComponent(hovering ? 0.28 : 0.12).cgColor
            self.transform = hovering
                ? CGAffineTransform(scaleX: 1.02, y: 1.02)
                : .identity
            self.hintLabel.textColor = UIColor.white
                .withAlphaComponent(hovering ? 0.7 : 0.45)
        }
    }

    @objc
    private func handleTap() {
        guard let code = code, !code.isEmpty else { return }
        UIPasteboard.general.string = code
        showCopiedFeedback()
        // Light haptic where available.
        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func showCopiedFeedback() {
        feedbackResetWork?.cancel()
        let previousHint = "Click to copy"
        hintLabel.text = "Copied!"
        accessibilityLabel = "\(code ?? "") copied"
        MotionStyle.animateChrome(duration: 0.18) {
            self.backgroundColor = self.successBackground
            self.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
            self.hintLabel.textColor = UIColor.white.withAlphaComponent(0.9)
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        } completion: { _ in
            MotionStyle.animateChrome(duration: 0.16) {
                self.transform = self.isPointerInside
                    ? CGAffineTransform(scaleX: 1.02, y: 1.02)
                    : .identity
            }
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.feedbackResetWork = nil
            self.hintLabel.text = previousHint
            self.resetChrome(animated: true)
        }
        feedbackResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func resetChrome(animated: Bool) {
        let apply = {
            self.backgroundColor = self.isPointerInside
                ? self.hoverBackground
                : self.normalBackground
            self.layer.borderColor = UIColor.white
                .withAlphaComponent(self.isPointerInside ? 0.28 : 0.12).cgColor
            self.hintLabel.textColor = UIColor.white
                .withAlphaComponent(self.isPointerInside ? 0.7 : 0.45)
            if !self.isPointerInside {
                self.transform = .identity
            }
        }
        if animated {
            MotionStyle.animateChrome(duration: 0.18, animations: apply)
        } else {
            apply()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            guard feedbackResetWork == nil else { return }
            backgroundColor = isHighlighted ? pressedBackground : (
                isPointerInside ? hoverBackground : normalBackground
            )
        }
    }
}

@available(iOS 13.4, *)
extension DeviceCodeChipView: UIPointerInteractionDelegate {
    func pointerInteraction(
        _ interaction: UIPointerInteraction,
        styleFor region: UIPointerRegion
    ) -> UIPointerStyle? {
        let preview = UITargetedPreview(view: self)
        return UIPointerStyle(effect: .highlight(preview))
    }
}
