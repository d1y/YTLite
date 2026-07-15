import UIKit

/// Library segment chrome — **platform split**:
/// - **Mac**: icon + localized title (composite image; UISegmentedControl is
///   image XOR title per Apple docs).
/// - **iOS**: icon only (no visible text).
enum LibrarySegmentChrome {
    enum Segment: Int, CaseIterable {
        case history = 0
        case downloads = 1
        case playlists = 2
    }

    /// Mac keeps 图标+文字; iOS is icons-only.
    static var showsSegmentTitles: Bool {
        PlatformStyle.isMac
    }

    static func systemImageName(for segment: Segment) -> String {
        switch segment {
        case .history:
            return "clock"
        case .downloads:
            return "arrow.down.circle"
        case .playlists:
            return "list.bullet"
        }
    }

    static func title(for segment: Segment) -> String {
        switch segment {
        case .history:
            return L10n.tr(L10n.Library.history)
        case .downloads:
            return L10n.tr(L10n.Library.downloads)
        case .playlists:
            return L10n.tr(L10n.Library.playlists)
        }
    }

    static func accessibilityLabel(for segment: Segment) -> String {
        title(for: segment)
    }

    static var hostsSegmentOutsideNavBarOnMac: Bool {
        PlatformStyle.isMac
    }

    static let macHorizontalMargin: CGFloat = 24

    /// Nudge left so the pill lines up with the title-bar tabs (optical center).
    /// Negative = toward leading / left.
    static let macCenterXOffset: CGFloat = -32

    /// Width band for the Mac centered pill (icon+title needs room).
    static var macMaxSegmentWidth: CGFloat {
        showsSegmentTitles ? 420 : 220
    }

    static var macMinSegmentWidth: CGFloat {
        showsSegmentTitles ? 280 : 140
    }

    static func macCenteredSegmentWidth(measured: CGFloat) -> CGFloat {
        min(max(measured, macMinSegmentWidth), macMaxSegmentWidth)
    }

    /// Segment images for the current platform.
    static func segmentImages() -> [UIImage] {
        Segment.allCases.map { segmentImage(for: $0) }
    }

    static func segmentImage(for segment: Segment) -> UIImage {
        if showsSegmentTitles {
            return iconTitleComposite(for: segment)
        }
        return iconOnlyImage(for: segment)
    }

    // MARK: - iOS: icon only

    private static func iconOnlyImage(for segment: Segment) -> UIImage {
        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            if let image = UIImage(
                systemName: systemImageName(for: segment),
                withConfiguration: cfg
            )?.withRenderingMode(.alwaysTemplate) {
                return image
            }
        }
        return UIImage()
    }

    // MARK: - Mac: icon + title composite

    private static func iconTitleComposite(for segment: Segment) -> UIImage {
        let label = title(for: segment)
        if #available(iOS 13.0, *) {
            if let composite = renderIconTitleImage(
                systemName: systemImageName(for: segment),
                title: label
            ) {
                return composite
            }
        }
        return renderTitleOnlyImage(title: label)
    }

    static func compositeContentWidth(
        iconSide: CGFloat,
        gap: CGFloat,
        titleWidth: CGFloat,
        horizontalPadding: CGFloat
    ) -> CGFloat {
        horizontalPadding * 2 + iconSide + gap + titleWidth
    }

    /// Mac policy: composites are wide (icon+text). iOS: narrow icons.
    static func usesPlatformCorrectSegments(
        isMac: Bool,
        images: [UIImage]
    ) -> Bool {
        guard images.count == Segment.allCases.count else {
            return false
        }
        if isMac {
            // Icon+title composites are wider than a lone glyph.
            return images.allSatisfy { $0.size.width > 28 && $0.size.height > 0 }
        }
        // Icon-only glyphs stay narrow.
        return images.allSatisfy { $0.size.width > 0 && $0.size.width < 40 }
    }

    @available(iOS 13.0, *)
    private static func renderIconTitleImage(
        systemName: String,
        title: String
    ) -> UIImage? {
        let iconPoint: CGFloat = 14
        let font = UIFont.systemFont(ofSize: 13, weight: .medium)
        let gap: CGFloat = 5
        let hPad: CGFloat = 4
        let cfg = UIImage.SymbolConfiguration(pointSize: iconPoint, weight: .medium)
        guard let symbol = UIImage(systemName: systemName, withConfiguration: cfg) else {
            return nil
        }
        let titleSize = (title as NSString).size(withAttributes: [.font: font])
        let iconSide = max(symbol.size.width, symbol.size.height)
        let height = max(22, max(iconSide, titleSize.height) + 2)
        let width = compositeContentWidth(
            iconSide: iconSide,
            gap: gap,
            titleWidth: ceil(titleSize.width),
            horizontalPadding: hPad
        )
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let iconY = (height - symbol.size.height) / 2
            let iconX = hPad
            symbol.draw(in: CGRect(
                x: iconX,
                y: iconY,
                width: symbol.size.width,
                height: symbol.size.height
            ))
            let textX = iconX + iconSide + gap
            let textY = (height - titleSize.height) / 2
            (title as NSString).draw(
                at: CGPoint(x: textX, y: textY),
                withAttributes: [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
            )
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    private static func renderTitleOnlyImage(title: String) -> UIImage {
        let font = UIFont.systemFont(ofSize: 13, weight: .medium)
        let titleSize = (title as NSString).size(withAttributes: [.font: font])
        let hPad: CGFloat = 6
        let size = CGSize(
            width: ceil(titleSize.width) + hPad * 2,
            height: max(22, ceil(titleSize.height) + 2)
        )
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let textY = (size.height - titleSize.height) / 2
            (title as NSString).draw(
                at: CGPoint(x: hPad, y: textY),
                withAttributes: [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
            )
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}
