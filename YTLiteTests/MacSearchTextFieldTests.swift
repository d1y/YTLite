import XCTest
@testable import YTLite
import UIKit

/// Pins Apple-doc appearance paths used by Mac search so typed/IME text
/// cannot silently render with zero contrast.
final class MacSearchTextFieldTests: XCTestCase {
    func testDarkAppearanceSetsWhiteTextAndOpaqueFill() {
        let field = MacSearchTextField(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        field.applyVisibleTextAppearance(isDark: true)
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertNotNil(field.textColor)
        XCTAssertTrue(field.textColor!.getWhite(&white, alpha: &alpha))
        XCTAssertGreaterThanOrEqual(white, 0.95)
        XCTAssertNotNil(field.backgroundColor)
        // Fill must be opaque enough to contrast.
        field.backgroundColor!.getWhite(&white, alpha: &alpha)
        XCTAssertGreaterThanOrEqual(alpha, 0.99)
        XCTAssertNotNil(field.markedTextStyle?[.foregroundColor])
        XCTAssertNotNil(field.typingAttributes?[.foregroundColor])
        XCTAssertNotNil(field.defaultTextAttributes[.foregroundColor])
    }

    func testLightAppearanceSetsDarkText() {
        let field = MacSearchTextField(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        field.applyVisibleTextAppearance(isDark: false)
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(field.textColor!.getWhite(&white, alpha: &alpha))
        XCTAssertLessThanOrEqual(white, 0.15)
    }

    func testTextRectHasUsableHeightInside40ptField() {
        let field = MacSearchTextField(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 34, height: 22))
        field.leftViewMode = .always
        field.layoutIfNeeded()
        let bounds = field.bounds
        let textRect = field.textRect(forBounds: bounds)
        let editRect = field.editingRect(forBounds: bounds)
        XCTAssertGreaterThanOrEqual(textRect.height, 20, "text rect must fit 17pt glyphs")
        XCTAssertGreaterThanOrEqual(editRect.height, 20)
        XCTAssertGreaterThan(textRect.width, 100)
    }

    func testMarkedTextStyleConfiguredForIME() {
        let field = MacSearchTextField(frame: .zero)
        field.applyVisibleTextAppearance(isDark: true)
        let style = field.markedTextStyle
        XCTAssertNotNil(style)
        XCTAssertNotNil(style?[.foregroundColor], "IME pinyin needs visible marked text")
        XCTAssertNotNil(style?[.font])
    }
}
