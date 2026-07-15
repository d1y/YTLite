import UIKit

/// Policy for channel avatars: true circle, not continuous superellipse.
enum CircleAvatarStyle {
    /// Radius for a square avatar of the given side length.
    static func cornerRadius(side: CGFloat) -> CGFloat {
        side / 2
    }

    /// Whether the layer should use circular (not continuous) corners.
    static var prefersCircularCornerCurve: Bool {
        true
    }

    /// Apply circular clip to a view/layer used as a channel avatar.
    static func apply(to layer: CALayer, side: CGFloat) {
        layer.cornerRadius = cornerRadius(side: side)
        layer.masksToBounds = true
        if #available(iOS 13.0, *) {
            // Explicit circular — continuous (squircle) looks wrong for faces.
            layer.cornerCurve = .circular
        }
    }

    static func apply(to view: UIView, side: CGFloat) {
        apply(to: view.layer, side: side)
        view.clipsToBounds = true
    }

    /// Enforce a square frame then circular clip (fixes bar-item oval squash).
    static func applySquareCircle(to view: UIView, side: CGFloat) {
        let square = max(1, side)
        if abs(view.bounds.width - square) > 0.5
            || abs(view.bounds.height - square) > 0.5 {
            view.bounds.size = CGSize(width: square, height: square)
        }
        apply(to: view, side: square)
    }
}
