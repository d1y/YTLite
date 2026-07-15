import Foundation

final class OAuthClient {
    struct DeviceCodeResponse {
        let deviceCode: String
        let userCode: String
        let verificationURL: String
        let interval: Int
        let clientId: String
        let clientSecret: String
    }
    struct PollConfig {
        let deviceCode: String
        let clientId: String
        let clientSecret: String
        let interval: Int
    }
    static let shared = OAuthClient()
    private let deviceCodeURL = AppURLs.YouTubeOAuth.deviceCode
    let tokenURL = AppURLs.YouTubeOAuth.token
    private let scope =
        "http://gdata.youtube.com " +
        "https://www.googleapis.com/auth/youtube-paid-content"
    let keychainService = "com.ytvlite.oauth"
    let keychainAccount = "youtube"
    var tokens: OAuthTokens?
    var isSignedIn: Bool { tokens != nil }
    var isAnonymous: Bool {
        get {
            tokens == nil && UserDefaults.standard.bool(
                forKey: UserDefaultsKeys.Auth.isAnonymous
            )
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: UserDefaultsKeys.Auth.isAnonymous
            )
        }
    }
    /// Coalesce concurrent 401-driven refresh attempts.
    var isRefreshInFlight = false
    /// Debounce for `authorizationRequired` UI spam.
    var lastAuthorizationRequiredAt: TimeInterval = 0
    /// A RAW transport (no AuthorizingTransport) — OAuth's own token requests
    /// must never trigger the 401-refresh cross-cut, which would recurse.
    private let transport: HTTPTransport
    private init(transport: HTTPTransport = URLSessionTransport()) {
        self.transport = transport
        tokens = loadFromKeychain()
        if tokens != nil {
            // Survived relaunch with tokens → not anonymous.
            isAnonymous = false
            AppLog.auth("session restored isSignedIn=true")
        } else {
            AppLog.auth(
                "session restore empty anonymous=\(isAnonymous)"
            )
        }
    }
}

extension OAuthClient {
    static func match(
        pattern: String,
        in string: String,
        group: Int
    ) -> String? {
        let fullRange = NSRange(string.startIndex..., in: string)
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let result = regex.firstMatch(in: string, range: fullRange),
              let range = Range(result.range(at: group), in: string)
        else {
            return nil
        }
        return String(string[range])
    }
    func makePostRequest(
        urlString: String,
        body: [String: Any]
    ) -> HTTPRequest? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        // YouTube OAuth is picky about client fingerprints; send the same
        // TV/Cobalt identity used when scraping credentials.
        return HTTPRequest(
            method: .post,
            url: url,
            headers: [
                HTTPHeader.contentType: HTTPHeaderValue.contentTypeJSON,
                HTTPHeader.userAgent: UserAgent.cobaltTV,
                HTTPHeader.accept: "application/json",
                HTTPHeader.origin: AppURLs.YouTube.base,
                HTTPHeader.referer: AppURLs.YouTube.tv
            ],
            body: try? JSONSerialization.data(withJSONObject: body)
        )
    }
    func performRequest(
        _ request: HTTPRequest,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        // OAuth endpoints return meaningful bodies on non-2xx (e.g. the polling
        // "authorization_pending" 4xx), so the body is surfaced for any status.
        transport.send(request, cancellationToken: nil) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                completion(.success(response.data))
            }
        }
    }
}

extension OAuthClient {
    func requestDeviceCode(
        completion: @escaping (Result<DeviceCodeResponse, Error>) -> Void
    ) {
        fetchClientCredentials { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let (clientId, clientSecret)):
                self.doRequestDeviceCode(
                    clientId: clientId,
                    clientSecret: clientSecret,
                    completion: completion
                )
            }
        }
    }
    private func doRequestDeviceCode(
        clientId: String,
        clientSecret: String,
        completion: @escaping (Result<DeviceCodeResponse, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "client_id": clientId,
            "scope": scope,
            "device_id": UUID().uuidString,
            "device_model": "ytlr::"
        ]
        guard let url = URL(string: deviceCodeURL),
              let bodyData = try? JSONSerialization.data(withJSONObject: body)
        else {
            completion(.failure(APIError.invalidURL))
            return
        }
        let headers: [String: String] = [
            HTTPHeader.contentType: HTTPHeaderValue.contentTypeJSON,
            HTTPHeader.userAgent: UserAgent.cobaltTV,
            HTTPHeader.accept: "application/json",
            HTTPHeader.origin: AppURLs.YouTube.base,
            HTTPHeader.referer: AppURLs.YouTube.tv
        ]
        // Multi-proxy failover: broken system HTTPS:443 must not block SOCKS/TUN.
        OAuthNetworkClient.postJSON(
            url: url,
            body: bodyData,
            headers: headers
        ) { result in
            switch result {
            case .failure(let error):
                AppLog.auth("device code request failed: \(error)")
                completion(.failure(OAuthFlowError.network(underlying: error)))
            case .success(let data):
                self.parseDeviceCodeResponse(
                    data: data,
                    clientId: clientId,
                    clientSecret: clientSecret,
                    completion: completion
                )
            }
        }
    }
    private func parseDeviceCodeResponse(
        data: Data,
        clientId: String,
        clientSecret: String,
        completion: @escaping (Result<DeviceCodeResponse, Error>) -> Void
    ) {
        let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
        guard let json = try? JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any] else {
            AppLog.auth("requestDeviceCode non-JSON: \(raw.prefix(400))")
            completion(.failure(APIError.decodingFailed))
            return
        }
        // Surface Google's error instead of a generic decode failure.
        if let err = json["error"] as? String {
            let desc = json["error_description"] as? String ?? err
            AppLog.auth("requestDeviceCode rejected: \(err) \(desc)")
            completion(.failure(OAuthFlowError.server(message: desc)))
            return
        }
        guard let deviceCode = json["device_code"] as? String,
              let userCode = json["user_code"] as? String,
              let verURL = json["verification_url"] as? String,
              let interval = Self.jsonInt(json["interval"])
        else {
            AppLog.auth("requestDeviceCode missing fields: \(raw.prefix(400))")
            completion(.failure(APIError.decodingFailed))
            return
        }
        let response = DeviceCodeResponse(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationURL: verURL,
            interval: max(interval, 1),
            clientId: clientId,
            clientSecret: clientSecret
        )
        completion(.success(response))
    }

    /// JSON numbers often arrive as `NSNumber` / `Double` from `JSONSerialization`.
    static func jsonInt(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let d = value as? Double { return Int(d) }
        if let s = value as? String { return Int(s) }
        return nil
    }
}

/// User-visible OAuth failures (device code / token exchange).
enum OAuthFlowError: LocalizedError {
    case server(message: String)
    case network(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message
        case .network(let underlying):
            return NetworkSessionFactory.describe(underlying)
        }
    }
}

extension OAuthClient {
    func validToken(
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let tokens else {
            // Only prompt when the user was expected to be signed in.
            // Anonymous browsing must not spam the device-code sheet.
            if !isAnonymous {
                postAuthorizationRequiredIfAllowed()
            }
            completion(.failure(APIError.unauthorized))
            return
        }
        if !tokens.isExpired {
            AppLog.auth("using cached token")
            completion(.success(tokens.accessToken))
            return
        }
        doRefresh(tokens: tokens, completion: completion)
    }
    func doRefresh(
        tokens: OAuthTokens,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "client_id": tokens.clientId,
            "client_secret": tokens.clientSecret,
            "refresh_token": tokens.refreshToken,
            "grant_type": "refresh_token"
        ]
        guard let request = makePostRequest(
            urlString: tokenURL,
            body: body
        ) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        performRequest(request) { [weak self] result in
            switch result {
            case .failure(let error):
                AppLog.auth(
                    "refresh request failed: \(error.localizedDescription)"
                )
                completion(
                    .failure(
                        OAuthRefreshFailure(
                            oauthErrorCode: nil,
                            detail: error.localizedDescription,
                            isTransportFailure: true
                        )
                    )
                )
            case .success(let data):
                self?.handleRefreshResponse(
                    data: data,
                    tokens: tokens,
                    completion: completion
                )
            }
        }
    }
    private func handleRefreshResponse(
        data: Data,
        tokens: OAuthTokens,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let json = try? JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any]
        else {
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            AppLog.auth(
                "refresh failed: unparseable response: \(raw.prefix(300))"
            )
            completion(
                .failure(
                    OAuthRefreshFailure(
                        oauthErrorCode: nil,
                        detail: "unparseable refresh response",
                        isTransportFailure: false
                    )
                )
            )
            return
        }
        guard let accessToken = json["access_token"] as? String,
              let expiresIn = Self.jsonInt(json["expires_in"])
        else {
            let code = json["error"] as? String
            let detail = json["error_description"] as? String ?? ""
            AppLog.auth(
                "refresh rejected: \(code ?? "nil") \(detail)"
            )
            completion(
                .failure(
                    OAuthRefreshFailure(
                        oauthErrorCode: code,
                        detail: detail,
                        isTransportFailure: false
                    )
                )
            )
            return
        }
        var updated = tokens
        updated.accessToken = accessToken
        updated.expiryDate = Date().addingTimeInterval(
            TimeInterval(expiresIn)
        )
        self.tokens = updated
        isAnonymous = false
        saveToKeychain(updated)
        AppLog.auth("token refreshed")
        completion(.success(accessToken))
    }

    /// Debounced re-auth UI signal (device-code sheet).
    func postAuthorizationRequiredIfAllowed() {
        let now = Date().timeIntervalSince1970
        guard OAuthRefreshPolicy.shouldPostAuthRequired(
            now: now,
            lastPostedAt: lastAuthorizationRequiredAt
        ) else {
            AppLog.auth("authorizationRequired debounced")
            return
        }
        lastAuthorizationRequiredAt = now
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .authorizationRequired,
                object: nil
            )
        }
    }

    func signOut() {
        tokens = nil
        isAnonymous = false
        isRefreshInFlight = false
        deleteFromKeychain()
        AppLog.auth("signed out")
    }
}
