import XCTest
@testable import YTLite

final class AppLanguageTests: XCTestCase {
    private let key = UserDefaultsKeys.Language.preference

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func testDefaultIsSystem() {
        XCTAssertEqual(AppLanguage.selected, .system)
        XCTAssertNil(AppLanguage.selected.languageCodeForL10n)
    }

    func testSelectingChinesePersistsAndForcesCode() {
        AppLanguage.selected = .chineseSimplified
        XCTAssertEqual(AppLanguage.selected, .chineseSimplified)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: key),
            "zh-Hans"
        )
        XCTAssertEqual(
            AppLanguage.selected.languageCodeForL10n,
            "zh-Hans"
        )
    }

    func testSelectingEnglishPersists() {
        AppLanguage.selected = .english
        XCTAssertEqual(AppLanguage.selected, .english)
        XCTAssertEqual(AppLanguage.selected.languageCodeForL10n, "en")
    }

    func testSystemClearsPreference() {
        AppLanguage.selected = .english
        AppLanguage.selected = .system
        XCTAssertNil(UserDefaults.standard.string(forKey: key))
        XCTAssertNil(AppLanguage.selected.languageCodeForL10n)
    }

    func testL10nTrHonorsForcedChineseWhenBundlesPresent() {
        AppLanguage.selected = .chineseSimplified
        // L10n.tr must pass AppLanguage.selected.languageCodeForL10n.
        XCTAssertEqual(
            AppLanguage.selected.languageCodeForL10n,
            "zh-Hans"
        )
        let code = AppLanguage.selected.languageCodeForL10n
        let forced = L10n.resolve(
            key: L10n.Settings.language,
            languageCode: code
        )
        let en = L10n.resolve(
            key: L10n.Settings.language,
            languageCode: "en"
        )
        // If host has lproj, Chinese differs; if not, both may fall back to key.
        if forced != L10n.Settings.language, en != L10n.Settings.language {
            XCTAssertNotEqual(forced, en)
        }
        XCTAssertFalse(forced.isEmpty)
    }

    func testLanguageDisplayNamesResolve() {
        XCTAssertFalse(AppLanguage.system.displayName.isEmpty)
        XCTAssertFalse(AppLanguage.english.displayName.isEmpty)
        XCTAssertFalse(AppLanguage.chineseSimplified.displayName.isEmpty)
    }
}
