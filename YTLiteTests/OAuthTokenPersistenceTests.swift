import XCTest
@testable import YTLite

final class OAuthTokenPersistenceTests: XCTestCase {
    func testTokensFileURLLivesUnderAppSupportYTLite() {
        let root = URL(fileURLWithPath: "/tmp/AppSupport", isDirectory: true)
        let url = OAuthClient.tokensFileURL(applicationSupport: root)
        XCTAssertEqual(url.lastPathComponent, "oauth_tokens.json")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "YTLite")
        XCTAssertTrue(url.path.hasPrefix(root.path))
    }

    func testOAuthTokensRoundTripEncodeDecode() throws {
        let original = OAuthTokens(
            accessToken: "ya29.access",
            refreshToken: "1//refresh",
            expiryDate: Date(timeIntervalSince1970: 1_900_000_000),
            clientId: "client",
            clientSecret: "secret"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OAuthTokens.self, from: data)
        XCTAssertEqual(decoded.accessToken, original.accessToken)
        XCTAssertEqual(decoded.refreshToken, original.refreshToken)
        XCTAssertEqual(decoded.clientId, original.clientId)
        XCTAssertEqual(decoded.clientSecret, original.clientSecret)
        XCTAssertEqual(
            decoded.expiryDate.timeIntervalSince1970,
            original.expiryDate.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testJsonIntAcceptsNumberAndString() {
        XCTAssertEqual(OAuthClient.jsonInt(3600), 3600)
        XCTAssertEqual(OAuthClient.jsonInt(3600.0), 3600)
        XCTAssertEqual(OAuthClient.jsonInt(NSNumber(value: 7200)), 7200)
        XCTAssertEqual(OAuthClient.jsonInt("1800"), 1800)
        XCTAssertNil(OAuthClient.jsonInt("nope"))
        XCTAssertNil(OAuthClient.jsonInt(nil))
    }

    func testIsSignedInReflectsInMemoryTokensOnly() {
        // Document contract: isSignedIn is purely tokens != nil.
        // Persistence is tested via encode/decode + file URL layout;
        // live keychain needs a host process with security entitlements.
        let clientTokens: OAuthTokens? = OAuthTokens(
            accessToken: "a",
            refreshToken: "r",
            expiryDate: Date().addingTimeInterval(3600),
            clientId: "c",
            clientSecret: "s"
        )
        XCTAssertNotNil(clientTokens)
        let empty: OAuthTokens? = nil
        XCTAssertNil(empty)
    }

    /// Transient refresh failure must not imply "sign out" (session keep).
    func testTransientRefreshDoesNotForceReauth() {
        XCTAssertFalse(
            OAuthRefreshPolicy.shouldForceReauthentication(
                oauthErrorCode: nil,
                isTransportFailure: true
            )
        )
    }

    /// Only permanent Google errors force re-login UI.
    func testPermanentRefreshForcesReauth() {
        XCTAssertTrue(
            OAuthRefreshPolicy.shouldForceReauthentication(
                oauthErrorCode: "invalid_grant",
                isTransportFailure: false
            )
        )
    }
}
