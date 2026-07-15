import Foundation

/// Pure policy for OAuth refresh failures — unit-tested without network.
///
/// Permanent Google errors mean the stored refresh token is dead → clear
/// session and ask the user to sign in again.
/// Transient/network/unknown errors must **not** wipe a working login
/// (that was the "I just logged in, why again?" bug on flaky Mac/proxy).
enum OAuthRefreshPolicy {
    /// OAuth `error` values that invalidate the stored refresh token.
    static let permanentErrorCodes: Set<String> = [
        "invalid_grant",
        "invalid_client",
        "unauthorized_client",
        "deleted_client",
        "access_denied",
        "invalid_token",
        "expired_token"
    ]

    /// Whether this failure should sign the user out and present re-auth.
    static func shouldForceReauthentication(
        oauthErrorCode: String?,
        isTransportFailure: Bool
    ) -> Bool {
        if isTransportFailure {
            return false
        }
        guard let raw = oauthErrorCode?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !raw.isEmpty else {
            // Unparseable / proxy HTML / empty — keep session, retry later.
            return false
        }
        return permanentErrorCodes.contains(raw.lowercased())
    }

    /// Minimum seconds between `authorizationRequired` posts (UI debounce).
    static let authRequiredDebounceSeconds: TimeInterval = 8

    static func shouldPostAuthRequired(
        now: TimeInterval,
        lastPostedAt: TimeInterval,
        debounce: TimeInterval = authRequiredDebounceSeconds
    ) -> Bool {
        now - lastPostedAt >= debounce
    }
}

/// Structured refresh failure for classification (not thrown across modules often).
struct OAuthRefreshFailure: Error {
    /// Google OAuth `error` field when present.
    let oauthErrorCode: String?
    let detail: String
    /// True when URLSession / reachability failed (no OAuth JSON body).
    let isTransportFailure: Bool

    var forcesReauthentication: Bool {
        OAuthRefreshPolicy.shouldForceReauthentication(
            oauthErrorCode: oauthErrorCode,
            isTransportFailure: isTransportFailure
        )
    }
}
