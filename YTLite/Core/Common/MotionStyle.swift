import UIKit

/// UIKit motion constants mapped from emilkowalski/skills design guidance
/// (ease-out enter, transform/opacity-first, press scale ~0.97, <300ms UI).
enum MotionStyle {
    // MARK: - Durations (seconds)

    /// Button / control press feedback.
    static let pressDuration: TimeInterval = 0.14
    /// Small chrome enter/exit (tooltips, control reveal).
    static let chromeDuration: TimeInterval = 0.2
    /// Panel / sheet-style transitions.
    static let panelDuration: TimeInterval = 0.25

    // MARK: - Scales

    /// Press feedback scale (skills: 0.95–0.98; 0.97 default).
    static let pressScale: CGFloat = 0.97
    /// Enter animation minimum scale (never animate from 0).
    static let enterScale: CGFloat = 0.95

    // MARK: - Timing

    /// Strong ease-out: cubic-bezier(0.23, 1, 0.32, 1).
    static var easeOut: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
    }

    /// Strong ease-in-out for on-screen movement.
    static var easeInOut: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.77, 0, 0.175, 1)
    }

    /// UIView animation options for enter-style chrome.
    static var easeOutOptions: UIView.AnimationOptions {
        [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
    }

    static var prefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    // MARK: - Animators

    /// Animate enter-style transitions with ease-out; respects reduced motion.
    static func animateChrome(
        duration: TimeInterval = chromeDuration,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        if prefersReducedMotion {
            animations()
            completion?(true)
            return
        }
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: easeOutOptions,
            animations: animations,
            completion: completion
        )
    }

    /// Scale press-in feedback on a control (transform + optional opacity).
    static func pressIn(_ view: UIView) {
        guard !prefersReducedMotion else { return }
        UIView.animate(
            withDuration: pressDuration,
            delay: 0,
            options: easeOutOptions,
            animations: {
                view.transform = CGAffineTransform(scaleX: pressScale, y: pressScale)
            },
            completion: nil
        )
    }

    /// Restore press scale.
    static func pressOut(_ view: UIView) {
        guard !prefersReducedMotion else {
            view.transform = .identity
            return
        }
        UIView.animate(
            withDuration: pressDuration,
            delay: 0,
            options: easeOutOptions,
            animations: {
                view.transform = .identity
            },
            completion: nil
        )
    }

    /// Install press scale feedback on a `UIControl` via target-action.
    static func installPressFeedback(on control: UIControl) {
        control.addTarget(
            PressFeedbackRelay.shared,
            action: #selector(PressFeedbackRelay.touchDown(_:)),
            for: .touchDown
        )
        control.addTarget(
            PressFeedbackRelay.shared,
            action: #selector(PressFeedbackRelay.touchUp(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
    }
}

/// Shared relay so we don't retain closures on every control.
private final class PressFeedbackRelay: NSObject {
    static let shared = PressFeedbackRelay()

    @objc
    func touchDown(_ sender: UIControl) {
        MotionStyle.pressIn(sender)
    }

    @objc
    func touchUp(_ sender: UIControl) {
        MotionStyle.pressOut(sender)
    }
}
