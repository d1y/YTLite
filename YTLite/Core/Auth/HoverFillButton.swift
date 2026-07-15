import UIKit

/// System button with desktop hover fill + press scale (open / retry actions).
final class HoverFillButton: UIButton {
    private var baseColor: UIColor = .systemRed
    private var hoverColor: UIColor = .systemRed
    private var isPointerInside = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        adjustsImageWhenHighlighted = false
        if #available(iOS 13.4, *) {
            addInteraction(UIPointerInteraction(delegate: self))
        }
        if #available(iOS 13.0, *) {
            installHoverGesture()
        }
        MotionStyle.installPressFeedback(on: self)
        addTarget(self, action: #selector(flashPress), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func applyFill(_ color: UIColor) {
        baseColor = color
        // Slightly lighter on hover for dark UIs.
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            hoverColor = UIColor(
                hue: h,
                saturation: max(s - 0.05, 0),
                brightness: min(b + 0.08, 1),
                alpha: a
            )
        } else {
            hoverColor = color.withAlphaComponent(0.88)
        }
        backgroundColor = baseColor
    }

    @available(iOS 13.0, *)
    private func installHoverGesture() {
        addGestureRecognizer(
            UIHoverGestureRecognizer(
                target: self,
                action: #selector(handleHover(_:))
            )
        )
    }

    @available(iOS 13.0, *)
    @objc
    private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            guard !isPointerInside else { return }
            isPointerInside = true
            MotionStyle.animateChrome(duration: 0.15) {
                self.backgroundColor = self.hoverColor
                self.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
            }
        case .ended, .cancelled:
            isPointerInside = false
            MotionStyle.animateChrome(duration: 0.15) {
                self.backgroundColor = self.baseColor
                self.transform = .identity
            }
        default:
            break
        }
    }

    @objc
    private func flashPress() {
        // Brief dip then restore — complements MotionStyle press scale.
        let flash = baseColor.withAlphaComponent(0.75)
        UIView.animate(withDuration: 0.08, animations: {
            self.backgroundColor = flash
        }, completion: { _ in
            MotionStyle.animateChrome(duration: 0.16) {
                self.backgroundColor = self.isPointerInside
                    ? self.hoverColor
                    : self.baseColor
            }
        })
        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

@available(iOS 13.4, *)
extension HoverFillButton: UIPointerInteractionDelegate {
    func pointerInteraction(
        _ interaction: UIPointerInteraction,
        styleFor region: UIPointerRegion
    ) -> UIPointerStyle? {
        UIPointerStyle(effect: .highlight(UITargetedPreview(view: self)))
    }
}
