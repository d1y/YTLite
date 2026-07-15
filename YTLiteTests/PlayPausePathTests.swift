import XCTest
@testable import YTLite

/// Proves the pure decision used by `VideoPlayerView.playPauseTapped`
/// for the fast pause path (play → pause must not wait on network).
final class PlayPausePathTests: XCTestCase {
    func testPlayingRateUsesPausePath() {
        XCTAssertTrue(
            ResponsiveMetrics.isPlayerActivelyPlaying(rate: 1.0)
        )
        XCTAssertTrue(
            ResponsiveMetrics.isPlayerActivelyPlaying(rate: 2.0)
        )
    }

    func testZeroRateUsesPlayPath() {
        XCTAssertFalse(
            ResponsiveMetrics.isPlayerActivelyPlaying(rate: 0)
        )
    }

    /// Documented contract: pause branch sets rate to 0 immediately
    /// (tested via helper; AVPlayer rate mutation is integration-only).
    func testPauseDecisionIsLocalRateCheckOnly() {
        // Simulate "currently playing" → handler takes pause branch.
        let rateWhilePlaying: Float = 1.0
        let shouldPause = ResponsiveMetrics.isPlayerActivelyPlaying(
            rate: rateWhilePlaying
        )
        XCTAssertTrue(shouldPause)

        // After local rate = 0, next tap resumes.
        let rateAfterPause: Float = 0
        XCTAssertFalse(
            ResponsiveMetrics.isPlayerActivelyPlaying(rate: rateAfterPause)
        )
    }
}
