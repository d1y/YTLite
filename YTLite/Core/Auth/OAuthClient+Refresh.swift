import Foundation

// MARK: - Token Refresh

extension OAuthClient {
    /// Called after API 401. Only forces re-login on **permanent** OAuth
    /// failures (e.g. `invalid_grant`). Network blips keep the session.
    func tryRefreshIfNeeded() {
        guard let tokens else {
            if !isAnonymous {
                postAuthorizationRequiredIfAllowed()
            }
            return
        }
        if isRefreshInFlight {
            AppLog.auth("refresh already in flight — skip duplicate 401")
            return
        }
        isRefreshInFlight = true
        doRefresh(tokens: tokens) { [weak self] result in
            guard let self else { return }
            self.isRefreshInFlight = false
            switch result {
            case .success:
                AppLog.auth("Token auto-refreshed on 401")
                UserDefaults.standard.set(
                    Date().timeIntervalSince1970,
                    forKey: "OAuthClient.lastRefresh"
                )
                self.notifyTokenRefreshed()
            case .failure(let error):
                self.handleRefreshFailure(error)
            }
        }
    }

    func refreshIfStale() {
        let lastRefresh = UserDefaults.standard.double(
            forKey: "OAuthClient.lastRefresh"
        )
        let interval: TimeInterval = 12 * 60 * 60
        guard Date().timeIntervalSince1970 - lastRefresh
            > interval
        else {
            return
        }
        guard let tokens else {
            return
        }
        if isRefreshInFlight {
            return
        }
        isRefreshInFlight = true
        doRefresh(tokens: tokens) { [weak self] result in
            guard let self else { return }
            self.isRefreshInFlight = false
            switch result {
            case .success:
                UserDefaults.standard.set(
                    Date().timeIntervalSince1970,
                    forKey: "OAuthClient.lastRefresh"
                )
                AppLog.auth("Periodic token refresh succeeded")
                self.notifyTokenRefreshed()
            case .failure(let error):
                // Periodic path: never force UI; only clear on permanent death.
                self.handleRefreshFailure(error, presentUI: false)
            }
        }
    }

    /// Shared failure handling for 401-driven and periodic refresh.
    func handleRefreshFailure(
        _ error: Error,
        presentUI: Bool = true
    ) {
        let failure = (error as? OAuthRefreshFailure)
            ?? OAuthRefreshFailure(
                oauthErrorCode: nil,
                detail: error.localizedDescription,
                isTransportFailure: true
            )
        let force = failure.forcesReauthentication
        AppLog.auth(
            "refresh failure forceReauth=\(force)"
                + " transport=\(failure.isTransportFailure)"
                + " code=\(failure.oauthErrorCode ?? "nil")"
                + " detail=\(failure.detail.prefix(120))"
        )
        if force {
            // Dead refresh token — clear so we don't loop on a corpse.
            signOut()
            if presentUI {
                postAuthorizationRequiredIfAllowed()
            }
        }
        // Transient: keep tokens on disk/memory; next request can retry.
    }

    private func notifyTokenRefreshed() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .tokenDidRefresh,
                object: nil
            )
        }
    }
}
