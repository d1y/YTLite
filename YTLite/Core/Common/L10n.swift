import Foundation

/// Localization entry point. Prefer `L10n.tr("key")` for user-visible chrome.
enum L10n {
    static let tableName = "Localizable"

    /// Resolve a localized string for the given key from the main bundle,
    /// honoring the Settings language preference when set.
    static func tr(_ key: String, bundle: Bundle = .main) -> String {
        resolve(
            key: key,
            languageCode: AppLanguage.selected.languageCodeForL10n,
            bundle: bundle
        )
    }

    /// Resolve a key under an explicit language code (`en`, `zh-Hans`, …).
    /// Used by unit tests and for forced-locale previews.
    static func resolve(
        key: String,
        languageCode: String?,
        bundle: Bundle = .main
    ) -> String {
        let source: Bundle
        if let languageCode,
           let path = bundle.path(forResource: languageCode, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            source = langBundle
        } else {
            source = bundle
        }
        return NSLocalizedString(
            key,
            tableName: tableName,
            bundle: source,
            value: key,
            comment: ""
        )
    }

    // MARK: - Primary chrome keys (compile-time constants)

    enum Tab {
        static let home = "tab.home"
        static let subscriptions = "tab.subscriptions"
        static let library = "tab.library"
    }

    enum Settings {
        static let title = "settings.title"
        static let theme = "settings.theme"
        static let themeDark = "settings.theme.dark"
        static let themeLight = "settings.theme.light"
        static let themeAuto = "settings.theme.auto"
        static let language = "settings.language"
        static let languageSystem = "settings.language.system"
        static let languageEnglish = "settings.language.english"
        static let languageChinese = "settings.language.chinese"
        static let languageFooter = "settings.language.footer"
        static let playback = "settings.playback"
        static let quality = "settings.quality"
        static let backgroundPlayback = "settings.background_playback"
        static let pip = "settings.pip"
        static let autoPip = "settings.auto_pip"
        static let hideStatusBar = "settings.hide_status_bar"
        static let showShorts = "settings.show_shorts"
        static let cache = "settings.cache"
        static let feedCache = "settings.feed_cache"
        static let imageCache = "settings.image_cache"
        static let clearCache = "settings.clear_cache"
        static let cancel = "settings.cancel"
        static let done = "settings.done"
        static let autoPipFooter = "settings.auto_pip.footer"
    }

    enum Common {
        static let done = "common.done"
        static let cancel = "common.cancel"
    }

    enum Library {
        static let history = "library.history"
        static let downloads = "library.downloads"
        static let playlists = "library.playlists"
    }
}

