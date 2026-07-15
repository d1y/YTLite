import XCTest
@testable import YTLite

final class L10nTests: XCTestCase {
    /// Bundle that owns the app localization resources (main when hosted in app,
    /// or the YTLite module bundle when available).
    private var resourceBundle: Bundle {
        // Prefer the app-under-test bundle so lproj folders resolve.
        Bundle(for: L10nTests.self)
            .url(forResource: "YTLite", withExtension: "app")
            .flatMap { Bundle(url: $0) }
            ?? Bundle.main
    }

    private func assertChinese(_ key: String, file: StaticString = #filePath, line: UInt = #line) {
        let zh = L10n.resolve(key: key, languageCode: "zh-Hans", bundle: resourceBundle)
        let en = L10n.resolve(key: key, languageCode: "en", bundle: resourceBundle)
        XCTAssertFalse(zh.isEmpty, "Chinese empty for \(key)", file: file, line: line)
        XCTAssertNotEqual(zh, key, "Chinese unresolved key \(key)", file: file, line: line)
        XCTAssertNotEqual(zh, en, "Chinese should differ from English for \(key)", file: file, line: line)
        // Chinese should contain CJK characters for primary chrome keys.
        let hasCJK = zh.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
        XCTAssertTrue(hasCJK, "Expected CJK in zh-Hans for \(key): \(zh)", file: file, line: line)
    }

    private func assertEnglish(_ key: String, expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let en = L10n.resolve(key: key, languageCode: "en", bundle: resourceBundle)
        let base = L10n.resolve(key: key, languageCode: "Base", bundle: resourceBundle)
        // Base may fall through to key if Base.lproj missing on host; en must match.
        XCTAssertEqual(en, expected, file: file, line: line)
        if base != key {
            XCTAssertEqual(base, expected, file: file, line: line)
        }
    }

    func testTabTitlesChineseAndEnglish() {
        assertEnglish(L10n.Tab.home, expected: "Home")
        assertEnglish(L10n.Tab.subscriptions, expected: "Subscriptions")
        assertEnglish(L10n.Tab.library, expected: "Library")
        assertChinese(L10n.Tab.home)
        assertChinese(L10n.Tab.subscriptions)
        assertChinese(L10n.Tab.library)
    }

    func testSettingsPrimaryChromeChineseAndEnglish() {
        assertEnglish(L10n.Settings.title, expected: "Settings")
        assertEnglish(L10n.Settings.pip, expected: "Picture-in-Picture")
        assertEnglish(L10n.Settings.autoPip, expected: "Auto Picture-in-Picture")
        assertEnglish(L10n.Settings.playback, expected: "Playback")
        assertChinese(L10n.Settings.title)
        assertChinese(L10n.Settings.pip)
        assertChinese(L10n.Settings.autoPip)
        assertChinese(L10n.Settings.playback)
        assertChinese(L10n.Settings.backgroundPlayback)
        assertChinese(L10n.Settings.theme)
    }

    func testAutoPipChineseLabelIsNotEnglish() {
        let zh = L10n.resolve(
            key: L10n.Settings.autoPip,
            languageCode: "zh-Hans",
            bundle: resourceBundle
        )
        XCTAssertEqual(zh, "自动画中画")
    }
}
