import UIKit

/// Mac Catalyst search field that always draws typed + IME marked text.
///
/// Apple docs (`UITextField.textColor`, `defaultTextAttributes`,
/// `typingAttributes`, `UITextInput.markedTextStyle`): appearance of both
/// committed and in-composition (pinyin) text must be configured explicitly.
/// Nested clear shells + `.none` border repeatedly produced invisible glyphs
/// on Catalyst while suggestions still received the string.
final class MacSearchTextField: UITextField {
    /// Horizontal inset after the magnifying-glass left view.
    private let textInsetX: CGFloat = 6
    private let textInsetY: CGFloat = 8

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func commonInit() {
        borderStyle = .none
        // Opaque fill set by theme — never clear.
        backgroundColor = UIColor(white: 0.22, alpha: 1)
        textColor = .white
        tintColor = .white
        font = UIFont.systemFont(ofSize: 17, weight: .regular)
        contentVerticalAlignment = .center
        adjustsFontSizeToFitWidth = false
        clearsOnBeginEditing = false
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        returnKeyType = .search
        clearButtonMode = .whileEditing
        // Critical for Chinese/Japanese IME composition underline + color.
        markedTextStyle = [
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.systemBlue.withAlphaComponent(0.35),
            .font: UIFont.systemFont(ofSize: 17, weight: .regular)
        ]
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .regular)
        ]
        defaultTextAttributes = attrs
        typingAttributes = attrs
    }

    /// Re-apply committed + marked text colors (theme / dark-light).
    func applyVisibleTextAppearance(isDark: Bool) {
        let textColor: UIColor = isDark ? .white : .black
        let fill = isDark
            ? UIColor(white: 0.28, alpha: 1)
            : UIColor(white: 0.95, alpha: 1)
        let secondary = isDark
            ? UIColor(white: 0.75, alpha: 1)
            : UIColor(white: 0.45, alpha: 1)
        let font = UIFont.systemFont(ofSize: 17, weight: .regular)

        backgroundColor = fill
        self.textColor = textColor
        tintColor = isDark ? .white : UIColor.systemBlue
        self.font = font
        keyboardAppearance = isDark ? .dark : .default
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = isDark ? .dark : .light
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: font
        ]
        // Docs: defaultTextAttributes applies to all current text.
        defaultTextAttributes = attrs
        typingAttributes = attrs
        markedTextStyle = [
            .foregroundColor: textColor,
            .backgroundColor: UIColor.systemBlue.withAlphaComponent(0.35),
            .font: font
        ]
        attributedPlaceholder = NSAttributedString(
            string: "Search YouTube",
            attributes: [
                .foregroundColor: secondary,
                .font: font
            ]
        )
        if let icon = leftView?.subviews.first as? UIImageView {
            icon.tintColor = secondary
        }
    }

    // MARK: - Geometry (ensure non-zero text rect on constrained height)

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        adjustedTextBounds(super.textRect(forBounds: bounds), bounds: bounds)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        adjustedTextBounds(super.editingRect(forBounds: bounds), bounds: bounds)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        adjustedTextBounds(
            super.placeholderRect(forBounds: bounds),
            bounds: bounds
        )
    }

    override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.clearButtonRect(forBounds: bounds)
        rect.origin.y = (bounds.height - rect.height) / 2
        return rect
    }

    override func leftViewRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.leftViewRect(forBounds: bounds)
        rect.origin.y = (bounds.height - rect.height) / 2
        return rect
    }

    private func adjustedTextBounds(
        _ rect: CGRect,
        bounds: CGRect
    ) -> CGRect {
        var r = rect
        // Guaranteed vertical room for 17pt glyphs inside a ~40pt field.
        let minH: CGFloat = 22
        if r.height < minH {
            r.size.height = min(minH, max(bounds.height - textInsetY * 2, minH))
            r.origin.y = (bounds.height - r.height) / 2
        }
        r = r.insetBy(dx: textInsetX, dy: 0)
        if r.width < 0 {
            r.size.width = 0
        }
        return r
    }
}
