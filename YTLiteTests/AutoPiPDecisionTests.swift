import XCTest
@testable import YTLite

final class AutoPiPDecisionTests: XCTestCase {
    private let suiteName = "AutoPiPDecisionTests.defaults"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testShouldAutoStartWhenAllConditionsMet() {
        let state = AutoPiPDecision.State(
            masterPiPEnabled: true,
            autoPiPEnabled: true,
            isPiPSupported: true,
            isPiPAlreadyActive: false,
            isFullscreen: false,
            isPlaying: true
        )
        XCTAssertTrue(AutoPiPDecision.shouldAutoStartPiP(state: state))
    }

    func testShouldNotAutoStartWhenAutoDisabled() {
        let state = AutoPiPDecision.State(
            masterPiPEnabled: true,
            autoPiPEnabled: false,
            isPiPSupported: true,
            isPiPAlreadyActive: false,
            isFullscreen: true,
            isPlaying: true
        )
        XCTAssertFalse(AutoPiPDecision.shouldAutoStartPiP(state: state))
    }

    func testShouldNotAutoStartWhenMasterDisabled() {
        let state = AutoPiPDecision.State(
            masterPiPEnabled: false,
            autoPiPEnabled: true,
            isPiPSupported: true,
            isPiPAlreadyActive: false,
            isFullscreen: false,
            isPlaying: true
        )
        XCTAssertFalse(AutoPiPDecision.shouldAutoStartPiP(state: state))
    }

    func testShouldNotAutoStartWhenUnsupported() {
        let state = AutoPiPDecision.State(
            masterPiPEnabled: true,
            autoPiPEnabled: true,
            isPiPSupported: false,
            isPiPAlreadyActive: false,
            isFullscreen: false,
            isPlaying: true
        )
        XCTAssertFalse(AutoPiPDecision.shouldAutoStartPiP(state: state))
    }

    func testShouldNotAutoStartWhenAlreadyActive() {
        let state = AutoPiPDecision.State(
            masterPiPEnabled: true,
            autoPiPEnabled: true,
            isPiPSupported: true,
            isPiPAlreadyActive: true,
            isFullscreen: false,
            isPlaying: true
        )
        XCTAssertFalse(AutoPiPDecision.shouldAutoStartPiP(state: state))
    }

    func testShouldNotAutoStartWhenNotPlaying() {
        let state = AutoPiPDecision.State(
            masterPiPEnabled: true,
            autoPiPEnabled: true,
            isPiPSupported: true,
            isPiPAlreadyActive: false,
            isFullscreen: true,
            isPlaying: false
        )
        XCTAssertFalse(AutoPiPDecision.shouldAutoStartPiP(state: state))
    }

    func testRetainControllerWhenAutoOnInline() {
        let state = AutoPiPDecision.State(
            masterPiPEnabled: true,
            autoPiPEnabled: true,
            isPiPSupported: true,
            isPiPAlreadyActive: false,
            isFullscreen: false,
            isPlaying: true
        )
        XCTAssertTrue(
            AutoPiPDecision.shouldRetainPiPControllerOnResign(state: state)
        )
    }

    func testRetainControllerLegacyFullscreenOnlyWhenAutoOff() {
        let fullscreen = AutoPiPDecision.State(
            masterPiPEnabled: true,
            autoPiPEnabled: false,
            isPiPSupported: true,
            isPiPAlreadyActive: false,
            isFullscreen: true,
            isPlaying: true
        )
        let inline = AutoPiPDecision.State(
            masterPiPEnabled: true,
            autoPiPEnabled: false,
            isPiPSupported: true,
            isPiPAlreadyActive: false,
            isFullscreen: false,
            isPlaying: true
        )
        XCTAssertTrue(
            AutoPiPDecision.shouldRetainPiPControllerOnResign(state: fullscreen)
        )
        XCTAssertFalse(
            AutoPiPDecision.shouldRetainPiPControllerOnResign(state: inline)
        )
    }

    func testPreferenceReadWrite() {
        let key = UserDefaultsKeys.Player.autoPiP
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertFalse(AutoPiPDecision.isAutoPiPEnabled)
        AutoPiPDecision.isAutoPiPEnabled = true
        XCTAssertTrue(AutoPiPDecision.isAutoPiPEnabled)
        XCTAssertEqual(UserDefaults.standard.object(forKey: key) as? Bool, true)
        AutoPiPDecision.isAutoPiPEnabled = false
        XCTAssertFalse(AutoPiPDecision.isAutoPiPEnabled)
        UserDefaults.standard.removeObject(forKey: key)
    }
}
