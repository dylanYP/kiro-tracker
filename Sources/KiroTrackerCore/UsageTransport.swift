import Foundation

// Refuse redirects so credentials stay on the original host.
final class RejectRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct UsageTransport: Sendable {
    static let maximumResponseBytes = 64 * 1024
    private let session: URLSession
    private let redirects = RejectRedirects()

    static func configuration() -> URLSessionConfiguration {
        // Keep cookies and credentials out of persistent storage.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 1
        return configuration
    }

    init() { session = URLSession(configuration: Self.configuration()) }
    // Let tests supply a session with fake responses.
    init(session: URLSession) { self.session = session }

    func fetch(_ request: URLRequest) async throws -> Data {
        let (bytes, response) = try await session.bytes(for: request, delegate: redirects)
        // Close the request when reading finishes or fails.
        defer { bytes.task.cancel() }
        guard let response = response as? HTTPURLResponse else { throw TrackerError.invalidUsage }
        if response.statusCode == 401 || response.statusCode == 403 { throw TrackerError.sessionExpired }
        guard response.statusCode == 200 else { throw TrackerError.server(response.statusCode) }
        guard response.expectedContentLength <= Self.maximumResponseBytes else { throw TrackerError.invalidUsage }
        var data = Data()
        data.reserveCapacity(min(Self.maximumResponseBytes, max(0, Int(response.expectedContentLength))))
        // Limit the body even when the server does not provide its size.
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < Self.maximumResponseBytes else { throw TrackerError.invalidUsage }
            data.append(byte)
        }
        return data
    }
}
