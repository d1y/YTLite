import UIKit

/// Player control icons drawn with UIBezierPath (iOS 12 compatible).
/// All glyphs accept an explicit `size` so large Mac windows can re-render
/// at responsive point sizes (not just grow empty hit boxes).
enum PlayerIcons {
    private struct CornerPoints {
        let corner: CGPoint
        let horizontal: CGPoint
        let vertical: CGPoint
    }

    // Phone defaults — preserved for call sites that omit size.
    static let defaultPlaySize: CGFloat = 44
    static let defaultSkipSize: CGFloat = 36
    static let defaultSettingsSize: CGFloat = 26
    static let defaultPipSize: CGFloat = 26
    static let defaultFullscreenSize: CGFloat = 24

    static func play(
        color: UIColor = .white,
        size: CGFloat = defaultPlaySize
    ) -> UIImage {
        let s = max(16, size).rounded()
        let key = "play#\(Int(s))"
        if let cached = vectorIconCache[key] {
            return cached
        }
        let img = draw(size: CGSize(width: s, height: s)) { _ in
            let scale = s / defaultPlaySize
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 14 * scale, y: 10 * scale))
            path.addLine(to: CGPoint(x: 36 * scale, y: 22 * scale))
            path.addLine(to: CGPoint(x: 14 * scale, y: 34 * scale))
            path.close()
            color.setFill()
            path.fill()
        }
        vectorIconCache[key] = img
        return img
    }

    static func pause(
        color: UIColor = .white,
        size: CGFloat = defaultPlaySize
    ) -> UIImage {
        let s = max(16, size).rounded()
        let key = "pause#\(Int(s))"
        if let cached = vectorIconCache[key] {
            return cached
        }
        let img = draw(size: CGSize(width: s, height: s)) { _ in
            let scale = s / defaultPlaySize
            color.setFill()
            let bar1 = CGRect(
                x: 12 * scale,
                y: 10 * scale,
                width: 7 * scale,
                height: 24 * scale
            )
            let bar2 = CGRect(
                x: 25 * scale,
                y: 10 * scale,
                width: 7 * scale,
                height: 24 * scale
            )
            UIBezierPath(roundedRect: bar1, cornerRadius: 2 * scale).fill()
            UIBezierPath(roundedRect: bar2, cornerRadius: 2 * scale).fill()
        }
        vectorIconCache[key] = img
        return img
    }

    static func rewind10(size: CGFloat = defaultSkipSize) -> UIImage {
        playerIcon("icon_Gobackward_10", size: max(16, size))
    }

    static func forward10(size: CGFloat = defaultSkipSize) -> UIImage {
        playerIcon("icon_Goforward_10", size: max(16, size))
    }

    static func settings(size: CGFloat = defaultSettingsSize) -> UIImage {
        playerIcon("icon_Gear", size: max(14, size))
    }

    static func pip(size: CGFloat = defaultPipSize) -> UIImage {
        let s = max(14, size)
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: s * 0.72, weight: .medium)
            if let img = UIImage(systemName: "pip.enter", withConfiguration: config) {
                return img.withTintColor(.white, renderingMode: .alwaysOriginal)
            }
        }
        return pipFallback(size: s)
    }

    static func pipExit(size: CGFloat = defaultPipSize) -> UIImage {
        let s = max(14, size)
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: s * 0.72, weight: .medium)
            if let img = UIImage(systemName: "pip.exit", withConfiguration: config) {
                return img.withTintColor(.white, renderingMode: .alwaysOriginal)
            }
        }
        return pip(size: s)
    }

    static func fullscreen(
        isFullscreen: Bool,
        size: CGFloat = defaultFullscreenSize
    ) -> UIImage {
        let s = max(14, size)
        return draw(size: CGSize(width: s, height: s)) { _ in
            let scale = s / defaultFullscreenSize
            UIColor.white.setStroke()
            let arm: CGFloat = 5 * scale
            let lineWidth: CGFloat = 2 * scale
            let corners = isFullscreen
                ? collapsedCorners(scale: scale)
                : expandedCorners(arm: arm, scale: scale)
            drawCorners(corners, lineWidth: lineWidth)
        }
    }

    /// Renders a named template/asset icon into a square of `size`.
    /// Used by watch action bar (like / share / save / download).
    /// Cached per (name, rounded size) — never re-rasterize every layout pass
    /// (that caused 0x8BADF00D watchdog + 1.2GB CG Raster Data).
    static func actionBarIcon(named name: String, size: CGFloat) -> UIImage? {
        let s = max(12, size).rounded()
        let key = "\(name)#\(Int(s))"
        if let cached = actionBarIconCache[key] {
            return cached
        }
        guard let img = UIImage(named: name) else { return nil }
        let iconSize = CGSize(width: s, height: s)
        let rendered = UIGraphicsImageRenderer(size: iconSize).image { _ in
            img.draw(in: CGRect(origin: .zero, size: iconSize))
        }.withRenderingMode(.alwaysTemplate)
        actionBarIconCache[key] = rendered
        return rendered
    }

    /// Clear raster caches (tests / memory pressure).
    static func clearActionBarIconCache() {
        actionBarIconCache.removeAll(keepingCapacity: false)
        vectorIconCache.removeAll(keepingCapacity: false)
        playerAssetIconCache.removeAll(keepingCapacity: false)
    }

    private static var actionBarIconCache: [String: UIImage] = [:]
    private static var vectorIconCache: [String: UIImage] = [:]
    private static var playerAssetIconCache: [String: UIImage] = [:]
}

// MARK: - Private helpers

extension PlayerIcons {
    private static func pipFallback(size: CGFloat) -> UIImage {
        let s = max(14, size)
        return draw(size: CGSize(width: s, height: s)) { _ in
            let scale = s / defaultPipSize
            UIColor.white.setStroke()
            let outerRect = CGRect(
                x: 2 * scale,
                y: 5 * scale,
                width: 22 * scale,
                height: 16 * scale
            )
            let outer = UIBezierPath(roundedRect: outerRect, cornerRadius: 2 * scale)
            outer.lineWidth = 1.5 * scale
            outer.stroke()
            UIColor.white.setFill()
            let innerRect = CGRect(
                x: 12 * scale,
                y: 11 * scale,
                width: 10 * scale,
                height: 7 * scale
            )
            UIBezierPath(roundedRect: innerRect, cornerRadius: 1 * scale).fill()
        }
    }

    /// Asset → square template; **cached** (layout thrash was 0x8BADF00D).
    private static func playerIcon(_ name: String, size: CGFloat) -> UIImage {
        let s = max(12, size).rounded()
        let key = "\(name)#\(Int(s))"
        if let cached = playerAssetIconCache[key] {
            return cached
        }
        let iconSize = CGSize(width: s, height: s)
        let renderer = UIGraphicsImageRenderer(size: iconSize)
        let img = renderer.image { _ in
            UIColor.white.setFill()
            UIImage(named: name)?.draw(
                in: CGRect(origin: .zero, size: iconSize)
            )
        }.withRenderingMode(.alwaysOriginal)
        playerAssetIconCache[key] = img
        return img
    }

    private static func draw(size: CGSize, block: (CGContext) -> Void) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }
        block(ctx)
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }
        UIGraphicsEndImageContext()
        return image.withRenderingMode(.alwaysOriginal)
    }

    private static func expandedCorners(
        arm: CGFloat,
        scale: CGFloat
    ) -> [CornerPoints] {
        [
            CornerPoints(
                corner: CGPoint(x: 3 * scale, y: 3 * scale),
                horizontal: CGPoint(x: 3 * scale + arm, y: 3 * scale),
                vertical: CGPoint(x: 3 * scale, y: 3 * scale + arm)
            ),
            CornerPoints(
                corner: CGPoint(x: 21 * scale, y: 3 * scale),
                horizontal: CGPoint(x: 21 * scale - arm, y: 3 * scale),
                vertical: CGPoint(x: 21 * scale, y: 3 * scale + arm)
            ),
            CornerPoints(
                corner: CGPoint(x: 3 * scale, y: 21 * scale),
                horizontal: CGPoint(x: 3 * scale + arm, y: 21 * scale),
                vertical: CGPoint(x: 3 * scale, y: 21 * scale - arm)
            ),
            CornerPoints(
                corner: CGPoint(x: 21 * scale, y: 21 * scale),
                horizontal: CGPoint(x: 21 * scale - arm, y: 21 * scale),
                vertical: CGPoint(x: 21 * scale, y: 21 * scale - arm)
            )
        ]
    }

    private static func collapsedCorners(scale: CGFloat) -> [CornerPoints] {
        [
            CornerPoints(
                corner: CGPoint(x: 8 * scale, y: 8 * scale),
                horizontal: CGPoint(x: 3 * scale, y: 8 * scale),
                vertical: CGPoint(x: 8 * scale, y: 3 * scale)
            ),
            CornerPoints(
                corner: CGPoint(x: 16 * scale, y: 8 * scale),
                horizontal: CGPoint(x: 21 * scale, y: 8 * scale),
                vertical: CGPoint(x: 16 * scale, y: 3 * scale)
            ),
            CornerPoints(
                corner: CGPoint(x: 8 * scale, y: 16 * scale),
                horizontal: CGPoint(x: 3 * scale, y: 16 * scale),
                vertical: CGPoint(x: 8 * scale, y: 21 * scale)
            ),
            CornerPoints(
                corner: CGPoint(x: 16 * scale, y: 16 * scale),
                horizontal: CGPoint(x: 21 * scale, y: 16 * scale),
                vertical: CGPoint(x: 16 * scale, y: 21 * scale)
            )
        ]
    }

    private static func drawCorners(_ corners: [CornerPoints], lineWidth: CGFloat) {
        for cp in corners {
            let path = UIBezierPath()
            path.move(to: cp.horizontal)
            path.addLine(to: cp.corner)
            path.addLine(to: cp.vertical)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }
}

// MARK: - Skip icon

extension PlayerIcons {
    static func speed() -> UIImage {
        return draw(size: CGSize(width: 24, height: 24)) { _ in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor.white
            ]
            let str = NSAttributedString(
                string: "1x",
                attributes: attrs
            )
            let sz = str.size()
            str.draw(at: CGPoint(
                x: (24 - sz.width) / 2,
                y: (24 - sz.height) / 2
            ))
        }
    }
}

extension PlayerIcons {
    private static func skipIcon(forward: Bool) -> UIImage {
        return draw(size: CGSize(width: 44, height: 44)) { _ in
            let cx: CGFloat = 22
            let cy: CGFloat = 21
            let radius: CGFloat = 12
            drawSkipArc(
                cx: cx,
                cy: cy,
                radius: radius,
                forward: forward
            )
            drawSkipText(cx: cx, cy: cy)
        }
    }

    private static func drawSkipArc(
        cx: CGFloat,
        cy: CGFloat,
        radius: CGFloat,
        forward: Bool
    ) {
        let startAngle: CGFloat = forward
            ? (.pi / 6) : (.pi * 11 / 6)
        let endAngle: CGFloat = forward
            ? (.pi * 11 / 6) : (.pi / 6)
        let arc = UIBezierPath(
            arcCenter: CGPoint(x: cx, y: cy),
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: forward
        )
        arc.lineWidth = 2.2
        arc.lineCapStyle = .butt
        UIColor.white.setStroke()
        arc.stroke()
        let ex = cx + radius * cos(endAngle)
        let ey = cy + radius * sin(endAngle)
        let velX: CGFloat = forward
            ? -sin(endAngle) : sin(endAngle)
        let velY: CGFloat = forward
            ? cos(endAngle) : -cos(endAngle)
        drawSkipArrowhead(
            endpoint: CGPoint(x: ex, y: ey),
            velocityAngle: atan2(velY, velX)
        )
    }

    private static func drawSkipArrowhead(
        endpoint: CGPoint,
        velocityAngle: CGFloat
    ) {
        let armLen: CGFloat = 5.5
        let spread: CGFloat = 0.45
        let arrow = UIBezierPath()
        arrow.move(to: CGPoint(
            x: endpoint.x + armLen * cos(velocityAngle + .pi + spread),
            y: endpoint.y + armLen * sin(velocityAngle + .pi + spread)
        ))
        arrow.addLine(to: endpoint)
        arrow.addLine(to: CGPoint(
            x: endpoint.x + armLen * cos(velocityAngle + .pi - spread),
            y: endpoint.y + armLen * sin(velocityAngle + .pi - spread)
        ))
        arrow.lineWidth = 2.2
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        UIColor.white.setStroke()
        arrow.stroke()
    }

    private static func drawSkipText(cx: CGFloat, cy: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.white
        ]
        let str = NSAttributedString(
            string: "10",
            attributes: attrs
        )
        let sz = str.size()
        str.draw(at: CGPoint(
            x: cx - sz.width / 2,
            y: cy - sz.height / 2 + 1
        ))
    }
}
