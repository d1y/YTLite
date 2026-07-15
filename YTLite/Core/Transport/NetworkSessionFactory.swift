import Foundation

/// App-wide `URLSession` factory.
///
/// **TUN / Enhanced mode (Clash, Surge, etc.):** traffic is routed at the
/// virtual NIC. The app must use a **plain direct** session — do **not** set
/// `connectionProxyDictionary`. Injecting system HTTP/SOCKS prefs (often
/// stale `127.0.0.1:443`) forces CONNECT to a dead local port and causes
/// `NSURLErrorCannotConnectToHost (-1004)` even when TUN is on and Safari works.
enum NetworkSessionFactory {
    static let shared: URLSession = makeDirectSession(ephemeral: false)
    static let cookieless: URLSession = makeDirectSession(ephemeral: true)

    static func makeDirectSession(ephemeral: Bool) -> URLSession {
        let config: URLSessionConfiguration = ephemeral ? .ephemeral : .default
        // Direct sockets → OS routing → TUN. No application-layer proxy.
        config.connectionProxyDictionary = [:]
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        config.allowsCellularAccess = true
        if #available(iOS 13.0, *) {
            config.allowsExpensiveNetworkAccess = true
            config.allowsConstrainedNetworkAccess = true
        }
        if ephemeral {
            config.httpCookieStorage = nil
            config.httpShouldSetCookies = false
            config.httpCookieAcceptPolicy = .never
        }
        AppLog.network("URLSession: direct (TUN/system route), no app-level proxy")
        return URLSession(configuration: config)
    }

    /// Kept for call sites that previously adopted a “working” proxy — always
    /// reset to direct so we never stick on a bad SOCKS/HTTP override.
    static func adoptWorkingProxy(_ proxy: [AnyHashable: Any]?) {
        _ = proxy
        AppLog.network("Ignoring proxy adopt — always direct for TUN compatibility")
    }

    static func describe(_ error: Error) -> String {
        if let api = error as? APIError, case .transport(let inner) = api {
            return describe(inner)
        }
        if let oauth = error as? OAuthFlowError, case .network(let inner) = oauth {
            return describe(inner)
        }

        let ns = error as NSError
        var lines: [String] = [ns.localizedDescription]
        if let url = ns.userInfo[NSURLErrorFailingURLStringErrorKey] as? String {
            lines.append("URL: \(url)")
        }
        lines.append("(\(ns.domain) \(ns.code))")

        if ns.code == NSURLErrorCannotConnectToHost
            || ns.code == NSURLErrorTimedOut
            || ns.code == NSURLErrorNetworkConnectionLost {
            lines.append("")
            lines.append(
                "App uses direct sockets (for TUN). If this persists, check "
                    + "the proxy app’s process list includes YTLite, or try "
                    + "Continue Anonymously."
            )
        }
        return lines.joined(separator: "\n")
    }
}
