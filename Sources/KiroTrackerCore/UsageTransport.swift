import Foundation

// Stateless delegate: no request, token, response body, or error is ever logged.
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
    // Only used by tests to supply an in-process URLProtocol with fake credentials.
    init(session: URLSession) { self.session = session }

    func fetch(_ request: URLRequest) async throws -> Data {
        let (bytes, response) = try await session.bytes(for: request, delegate: redirects)
        // Cancel immediately on rejected status, oversized bodies, or consumer cancellation.
        defer { bytes.task.cancel() }
        guard let response = response as? HTTPURLResponse else { throw TrackerError.invalidUsage }
        if response.statusCode == 401 || response.statusCode == 403 { throw TrackerError.sessionExpired }
        guard response.statusCode == 200 else { throw TrackerError.server(response.statusCode) }
        guard response.expectedContentLength <= Self.maximumResponseBytes else { throw TrackerError.invalidUsage }
        var data = Data()
        data.reserveCapacity(min(Self.maximumResponseBytes, max(0, Int(response.expectedContentLength))))
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < Self.maximumResponseBytes else { throw TrackerError.invalidUsage }
            data.append(byte)
        }
        return data
    }
}
