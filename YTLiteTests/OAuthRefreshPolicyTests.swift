import XCTest
@testable import YTLite

final class OAuthRefreshPolicyTests: XCTestCase {
    func testPermanentInvalidGrantForcesReauth() {
        XCTAssertTrue(
            OAuthRefreshPolicy.shouldForceReauthentication(
                oauthErrorCode: "invalid_grant",
                isTransportFailure: false
            )
        )
        XCTAssertTrue(
            OAuthRefreshPolicy.shouldForceReauthentication(
                oauthErrorCode: "INVALID_GRANT",
                isTransportFailure: false
            )
        )
    }

    func testNetworkFailureNeverForcesReauth() {
        XCTAssertFalse(
            OAuthRefreshPolicy.shouldForceReauthentication(
                oauthErrorCode: "invalid_grant",
                isTransportFailure: true
            )
        )
        XCTAssertFalse(
            OAuthRefreshPolicy.shouldForceReauthentication(
                oauthErrorCode: nil,
                isTransportFailure: true
            )
        )
    }

    func testUnknownOrEmptyCodeKeepsSession() {
        XCTAssertFalse(
            OAuthRefreshPolicy.shouldForceReauthentication(
                oauthErrorCode: nil,
                isTransportFailure: false
            )
        )
        XCTAssertFalse(
            OAuthRefreshPolicy.shouldForceReauthentication(
                oauthErrorCode: "  ",
                isTransportFailure: false
            )
        )
        XCTAssertFalse(
            OAuthRefreshPolicy.shouldForceReauthentication(
                oauthErrorCode: "server_error",
                isTransportFailure: false
            )
        )
    }

    func testOAuthRefreshFailureStructMatchesPolicy() {
        let permanent = OAuthRefreshFailure(
            oauthErrorCode: "invalid_grant",
            detail: "expired",
            isTransportFailure: false
        )
        XCTAssertTrue(permanent.forcesReauthentication)

        let network = OAuthRefreshFailure(
            oauthErrorCode: nil,
            detail: "offline",
            isTransportFailure: true
        )
        XCTAssertFalse(network.forcesReauthentication)
    }

    func testAuthRequiredDebounce() {
        XCTAssertTrue(
            OAuthRefreshPolicy.shouldPostAuthRequired(
                now: 100,
                lastPostedAt: 0,
                debounce: 8
            )
        )
        XCTAssertFalse(
            OAuthRefreshPolicy.shouldPostAuthRequired(
                now: 105,
                lastPostedAt: 100,
                debounce: 8
            )
        )
        XCTAssertTrue(
            OAuthRefreshPolicy.shouldPostAuthRequired(
                now: 109,
                lastPostedAt: 100,
                debounce: 8
            )
        )
    }
}
