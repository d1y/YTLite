import Foundation

/// Pure decision logic for automatic Picture-in-Picture on backgrounding.
/// Unit-testable without launching the player UI.
enum AutoPiPDecision {
    /// Snapshot of playback / preference state used for decisions.
    struct State: Equatable {
        /// Master PiP toggle (settings “Picture-in-Picture”).
        var masterPiPEnabled: Bool
        /// Auto-PiP option (settings “Auto Picture-in-Picture”).
        var autoPiPEnabled: Bool
        /// Device / OS supports `AVPictureInPictureController`.
        var isPiPSupported: Bool
        /// PiP session already active.
        var isPiPAlreadyActive: Bool
        /// Player is currently fullscreen.
        var isFullscreen: Bool
        /// Playback was running when leaving the foreground.
        var isPlaying: Bool
    }

    /// Whether the app should attempt to start PiP when backgrounding.
    static func shouldAutoStartPiP(state: State) -> Bool {
        guard state.masterPiPEnabled,
              state.autoPiPEnabled,
              state.isPiPSupported,
              !state.isPiPAlreadyActive,
              state.isPlaying
        else {
            return false
        }
        return true
    }

    /// Whether to keep the PiP controller alive on `willResignActive`.
    /// Keeping it allows the system / explicit start to enter PiP.
    /// When auto-PiP is off, only fullscreen retains the controller
    /// (legacy behaviour — avoids accidental auto-PiP while still allowing
    /// background audio after the layer is detached).
    static func shouldRetainPiPControllerOnResign(state: State) -> Bool {
        guard state.masterPiPEnabled, state.isPiPSupported else {
            return false
        }
        if state.autoPiPEnabled {
            return true
        }
        return state.isFullscreen
    }

    // MARK: - Preference accessors

    static var isAutoPiPEnabled: Bool {
        get {
            UserDefaults.standard.object(
                forKey: UserDefaultsKeys.Player.autoPiP
            ) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: UserDefaultsKeys.Player.autoPiP
            )
        }
    }

    static var isMasterPiPEnabled: Bool {
        UserDefaults.standard.object(
            forKey: UserDefaultsKeys.Player.pipEnabled
        ) as? Bool ?? true
    }

    /// Build state from live preferences + runtime flags.
    static func makeState(
        isPiPSupported: Bool,
        isPiPAlreadyActive: Bool,
        isFullscreen: Bool,
        isPlaying: Bool
    ) -> State {
        State(
            masterPiPEnabled: isMasterPiPEnabled,
            autoPiPEnabled: isAutoPiPEnabled,
            isPiPSupported: isPiPSupported,
            isPiPAlreadyActive: isPiPAlreadyActive,
            isFullscreen: isFullscreen,
            isPlaying: isPlaying
        )
    }
}
