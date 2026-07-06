import UIKit

// MARK: - Navigation chevrons (pre-iOS 13 fallback)

// No SF Symbols before iOS 13 — draw the chevrons to match the system back
// indicator (~12×21pt, 3pt rounded stroke) so the watch screen's custom
// buttons look like the back button on every other screen.

extension PlayerIcons {
    enum NavChevron {
        case back
        case minimize
    }

    static func navChevron(_ kind: NavChevron) -> UIImage {
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
        return strokedPath(points: points, size: size)
    }

    private static func strokedPath(points: [CGPoint], size: CGSize) -> UIImage {
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
