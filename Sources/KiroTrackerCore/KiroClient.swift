import Foundation
import SQLite3

public actor KiroClient {
    private let databaseURL: URL
    private let session: URLSession

    public init(databaseURL: URL? = nil) {
        self.databaseURL = databaseURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/kiro-cli/data.sqlite3")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 25
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
    }

    public func fetch() async throws -> UsageSnapshot {
        // Re-read each time so the CLI remains the sole owner of login and token renewal.
        let credentials = try readCredentials()
        let arnParts = credentials.profile.arn.split(separator: ":", omittingEmptySubsequences: false)
        guard arnParts.count >= 6, arnParts[0] == "arn", arnParts[1] == "aws",
              arnParts[2] == "codewhisperer" else { throw TrackerError.unsupportedRegion }
        let endpoint: String
        switch arnParts[3] {
        case "us-east-1": endpoint = "https://codewhisperer.us-east-1.amazonaws.com/"
        case "eu-central-1": endpoint = "https://q.eu-central-1.amazonaws.com/"
        default: throw TrackerError.unsupportedRegion
        }
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.token.access_token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-amz-json-1.0", forHTTPHeaderField: "Content-Type")
        request.setValue("AmazonCodeWhispererService.GetUsageLimits", forHTTPHeaderField: "X-Amz-Target")
        request.setValue("KiroTracker/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["profileArn": credentials.profile.arn])
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw TrackerError.invalidUsage }
        if response.statusCode == 401 || response.statusCode == 403 { throw TrackerError.sessionExpired }
        guard (200..<300).contains(response.statusCode) else { throw TrackerError.server(response.statusCode) }
        return try UsageSnapshot.decode(data)
    }

    private struct Token: Decodable { let access_token: String }
    private struct Profile: Decodable { let arn: String }

    private func readCredentials() throws -> (token: Token, profile: Profile) {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }
            throw TrackerError.notSignedIn
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 1000)
        func read(_ sql: String) throws -> Data {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw TrackerError.notSignedIn
            }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let bytes = sqlite3_column_blob(statement, 0) else { throw TrackerError.notSignedIn }
            return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
        }
        do {
            let decoder = JSONDecoder()
            let token = try decoder.decode(Token.self, from: read("SELECT value FROM auth_kv WHERE key = 'kirocli:odic:token'"))
            let profile = try decoder.decode(Profile.self, from: read("SELECT value FROM state WHERE key = 'api.codewhisperer.profile'"))
            guard !token.access_token.isEmpty else { throw TrackerError.notSignedIn }
            return (token, profile)
        } catch { throw TrackerError.notSignedIn }
    }
}
