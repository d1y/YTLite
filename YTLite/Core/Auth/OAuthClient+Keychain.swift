import Foundation
import Security

/// Token persistence for OAuth.
///
/// Strategy:
/// 1. **Keychain** (preferred) — with Mac Catalyst–friendly attributes and
///    checked OSStatus (silent SecItemAdd failure was the main macOS bug:
///    login appeared to work in-memory, then next launch had no tokens).
/// 2. **Application Support file** (always written as durable fallback) —
///    ad-hoc / unsigned Catalyst builds frequently lose keychain access
///    across relaunch; file storage under the app container survives.
extension OAuthClient {
    // MARK: - Public persistence API

    func saveToKeychain(_ tokens: OAuthTokens) {
        let encoded: Data?
        do {
            encoded = try JSONEncoder().encode(tokens)
        } catch {
            AppLog.auth("token encode failed: \(error)")
            encoded = nil
        }
        guard let data = encoded else { return }

        let keychainOK = writeKeychain(data: data)
        let fileOK = writeFileFallback(data: data)
        AppLog.auth(
            "token persist keychain=\(keychainOK) file=\(fileOK)"
        )
    }

    func loadFromKeychain() -> OAuthTokens? {
        if let data = readKeychain(),
           let tokens = decodeTokens(data) {
            // Re-mirror to file so a later keychain-only wipe can recover.
            _ = writeFileFallback(data: data)
            AppLog.auth("token loaded from keychain")
            return tokens
        }
        if let data = readFileFallback(),
           let tokens = decodeTokens(data) {
            AppLog.auth("token loaded from file fallback")
            // Best-effort re-seed keychain for future launches.
            _ = writeKeychain(data: data)
            return tokens
        }
        AppLog.auth("token load: no keychain and no file")
        return nil
    }

    func deleteFromKeychain() {
        deleteKeychainItem()
        deleteFileFallback()
        AppLog.auth("token storage cleared")
    }

    // MARK: - Keychain

    private func baseKeychainQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        // Prefer the data-protection keychain on modern OS / Catalyst —
        // classic keychain often rejects ad-hoc signed Mac apps silently.
        if #available(iOS 13.0, macCatalyst 13.0, *) {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    @discardableResult
    private func writeKeychain(data: Data) -> Bool {
        var query = baseKeychainQuery()
        // AfterFirstUnlock: available after first unlock of the device/session,
        // works for background refresh and avoids "when unlocked" edge cases
        // that fail on Mac headless relaunch.
        query[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlock

        // Delete any prior item (ignore status).
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecSuccess {
            return true
        }
        // Duplicate → update in place.
        if status == errSecDuplicateItem {
            let update: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(
                query as CFDictionary,
                update as CFDictionary
            )
            if updateStatus == errSecSuccess {
                return true
            }
            AppLog.auth(
                "keychain update failed: \(updateStatus)"
            )
            return false
        }
        AppLog.auth("keychain add failed: \(status)")
        return false
    }

    private func readKeychain() -> Data? {
        var query = baseKeychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            return result as? Data
        }
        if status != errSecItemNotFound {
            AppLog.auth("keychain read failed: \(status)")
        }
        return nil
    }

    private func deleteKeychainItem() {
        let query = baseKeychainQuery()
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            AppLog.auth("keychain delete failed: \(status)")
        }
    }

    // MARK: - File fallback (Application Support)

    /// Pure path helper — unit-testable without writing disk.
    static func tokensFileURL(
        applicationSupport: URL
    ) -> URL {
        applicationSupport
            .appendingPathComponent("YTLite", isDirectory: true)
            .appendingPathComponent("oauth_tokens.json", isDirectory: false)
    }

    private var tokensFileURL: URL? {
        guard let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return Self.tokensFileURL(applicationSupport: root)
    }

    @discardableResult
    private func writeFileFallback(data: Data) -> Bool {
        guard let url = tokensFileURL else {
            AppLog.auth("file fallback: no Application Support URL")
            return false
        }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            // Restrict file permissions on Mac (owner read/write only).
            #if targetEnvironment(macCatalyst) || os(macOS)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
            #endif
            return true
        } catch {
            AppLog.auth("file fallback write failed: \(error)")
            return false
        }
    }

    private func readFileFallback() -> Data? {
        guard let url = tokensFileURL else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            AppLog.auth("file fallback read failed: \(error)")
            return nil
        }
    }

    private func deleteFileFallback() {
        guard let url = tokensFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func decodeTokens(_ data: Data) -> OAuthTokens? {
        do {
            return try JSONDecoder().decode(OAuthTokens.self, from: data)
        } catch {
            AppLog.auth("token decode failed: \(error)")
            return nil
        }
    }
}
