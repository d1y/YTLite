import Foundation

/// OAuth HTTP helper — **direct** `URLSession` so TUN/virtual NIC can route
/// traffic. No application-level HTTP/SOCKS proxy (that bypasses TUN and
/// often hits broken system prefs like `127.0.0.1:443`).
enum OAuthNetworkClient {
    static func postJSON(
        url: URL,
        body: Data,
        headers: [String: String],
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let session = NetworkSessionFactory.shared
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 25
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        AppLog.auth("OAuth POST \(url.absoluteString) (direct/TUN)")
        session.dataTask(with: request) { data, response, error in
            if let error {
                AppLog.auth("OAuth POST failed: \(error)")
                completion(.failure(error))
                return
            }
            guard response is HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            completion(.success(data ?? Data()))
        }.resume()
    }
}
