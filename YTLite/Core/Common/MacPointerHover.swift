import ObjectiveC
import UIKit

/// macOS / pointer-device hover affordances (Catalyst).
/// Mirrors the “cursor: pointer” expectation: clickable chrome shows
/// a highlight pointer and optional alpha lift on hover.
enum MacPointerHover {
    private static var installedKey: UInt8 = 0

    /// Install once per view. Safe to call repeatedly.
    static func install(on view: UIView) {
        guard ResponsiveMetrics.shouldInstallPointerHover(
            isMac: PlatformStyle.isMac
        ) else {
            return
        }
        if objc_getAssociatedObject(view, &installedKey) != nil {
            return
        }
        objc_setAssociatedObject(
            view,
            &installedKey,
            true,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        if #available(iOS 13.4, *) {
            view.addInteraction(
                UIPointerInteraction(delegate: PointerRelay.shared)
            )
        }
        if #available(iOS 13.0, *) {
            let hover = UIHoverGestureRecognizer(
                target: HoverTarget.shared,
                action: #selector(HoverTarget.handle(_:))
            )
            view.addGestureRecognizer(hover)
        }
    }

    static func install(on views: [UIView]) {
        views.forEach { install(on: $0) }
    }
}

@available(iOS 13.4, *)
private final class PointerRelay: NSObject, UIPointerInteractionDelegate {
    static let shared = PointerRelay()

    func pointerInteraction(
        _ interaction: UIPointerInteraction,
        styleFor region: UIPointerRegion
    ) -> UIPointerStyle? {
        guard let view = interaction.view else { return nil }
        // Lift + highlight ≈ CSS cursor:pointer affordance on Mac.
        return UIPointerStyle(
            effect: .highlight(UITargetedPreview(view: view))
        )
    }
}

@available(iOS 13.0, *)
private final class HoverTarget: NSObject {
    static let shared = HoverTarget()

    @objc
    func handle(_ gesture: UIHoverGestureRecognizer) {
        guard let view = gesture.view else { return }
        switch gesture.state {
        case .began, .changed:
            UIView.animate(withDuration: 0.12) {
                view.alpha = 0.85
            }
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.12) {
                view.alpha = 1
            }
        default:
            break
        }
    }
}
