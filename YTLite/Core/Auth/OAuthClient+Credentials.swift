import Foundation

extension OAuthClient {
    /// Public YouTube TV OAuth client embedded in youtube.com/tv (not a secret).
    /// Primary path for device login — scraping is only a best-effort upgrade.
    private static let fallbackTVClientId =
        "861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com"
    private static let fallbackTVClientSecret = "SboVhoG9s0rNafixCSGGKXAT"

    private static var fallbackCredentials: (String, String) {
        (fallbackTVClientId, fallbackTVClientSecret)
    }

    func fetchClientCredentials(
        completion: @escaping (Result<(String, String), Error>) -> Void
    ) {
        // Prefer the well-known public TV client first so sign-in still works
        // when youtube.com/tv is blocked, returns a consent wall, or times out
        // (common on restricted networks / some macOS environments).
        // Optionally try a live scrape in the background is not needed —
        // the embedded pair is what the official TV client ships.
        AppLog.auth(
            "Using embedded TV OAuth client " +
            "(id=\(Self.fallbackTVClientId.prefix(24))...)"
        )
        completion(.success(Self.fallbackCredentials))
    }
}
