import Foundation

/// User-selectable app language (Settings).
/// `system` follows the OS preferred languages; otherwise force `en` / `zh-Hans`.
enum AppLanguage: String, CaseIterable {
    case system
    case english = "en"
    case chineseSimplified = "zh-Hans"

    /// Persisted preference (empty / missing → system).
    static var selected: AppLanguage {
        get {
            let raw = UserDefaults.standard.string(
                forKey: UserDefaultsKeys.Language.preference
            )
            return raw.flatMap(AppLanguage.init(rawValue:)) ?? .system
        }
        set {
            if newValue == .system {
                UserDefaults.standard.removeObject(
                    forKey: UserDefaultsKeys.Language.preference
                )
            } else {
                UserDefaults.standard.set(
                    newValue.rawValue,
                    forKey: UserDefaultsKeys.Language.preference
                )
            }
            NotificationCenter.default.post(
                name: .appLanguageDidChange,
                object: nil
            )
        }
    }

    /// Language code passed to `L10n.resolve` (`nil` = system / main bundle).
    var languageCodeForL10n: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .chineseSimplified:
            return "zh-Hans"
        }
    }

    /// Settings UI label (resolved under current language).
    var displayName: String {
        switch self {
        case .system:
            return L10n.tr(L10n.Settings.languageSystem)
        case .english:
            return L10n.tr(L10n.Settings.languageEnglish)
        case .chineseSimplified:
            return L10n.tr(L10n.Settings.languageChinese)
        }
    }
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name(
        "YTLiteAppLanguageDidChange"
    )
}
