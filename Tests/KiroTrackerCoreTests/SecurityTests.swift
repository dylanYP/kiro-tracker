import Foundation
import SQLite3
import Darwin
import Testing
@testable import KiroTrackerCore

private let testARN = "arn:aws:codewhisperer:us-east-1:123456789012:profile/test"

@Test func nonRegularDatabaseCannotBlockOnAPipe() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let pipe = folder.appendingPathComponent("not-a-database")
    #expect(mkfifo(pipe.path, 0o600) == 0)
    #expect(throws: (any Error).self) { try CredentialStore.read(from: pipe) }
    #expect(throws: (any Error).self) { try CredentialStore.read(from: folder) }
}

@Test func credentialCannotControlDestinationOrInjectHeaders() throws {
    let request = try KiroClient.request(token: "fake-token", profileARN: testARN)
    #expect(request.url?.absoluteString == "https://codewhisperer.us-east-1.amazonaws.com/")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fake-token")
    #expect(try KiroClient.request(token: "fake", profileARN: testARN.replacingOccurrences(of: "us-east-1", with: "eu-central-1")).url?.host == "q.eu-central-1.amazonaws.com")
    for arn in ["https://attacker.invalid", testARN + "\n", testARN + ":extra", testARN.replacingOccurrences(of: "us-east-1", with: "attacker.invalid"), testARN.replacingOccurrences(of: "/test", with: "/../admin")] {
        #expect(throws: (any Error).self) { try KiroClient.request(token: "fake", profileARN: arn) }
    }
    for token in ["", "fake\r\nX-Injected: yes", "fake token", String(repeating: "a", count: 16_385)] {
        #expect(throws: (any Error).self) { try KiroClient.request(token: token, profileARN: testARN) }
    }
}

@Test func everyRedirectIsRefused() async {
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let original = URL(string: "https://codewhisperer.us-east-1.amazonaws.com/")!
    let task = session.dataTask(with: original) // Never resumed; no network traffic.
    for destination in ["https://attacker.invalid/", "http://codewhisperer.us-east-1.amazonaws.com/", original.absoluteString] {
        let refused = await withCheckedContinuation { continuation in
            RejectRedirects().urlSession(session, task: task,
                willPerformHTTPRedirection: HTTPURLResponse(url: original, statusCode: 307, httpVersion: nil, headerFields: nil)!,
                newRequest: URLRequest(url: URL(string: destination)!),
                completionHandler: { continuation.resume(returning: $0 == nil) })
        }
        #expect(refused)
    }
}

@Test func networkStateIsNotPersisted() {
    let configuration = UsageTransport.configuration()
    #expect(configuration.urlCache == nil)
    #expect(configuration.urlCredentialStorage == nil)
    #expect(configuration.httpCookieStorage == nil)
    #expect(!configuration.httpShouldSetCookies)
    #expect(configuration.timeoutIntervalForResource == 20)
}

private final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let status = path == "/unauthorized" ? 401 : path == "/redirect" ? 307 : 200
        let payload = path == "/valid" ? Data("{}".utf8) : Data(repeating: 65, count: UsageTransport.maximumResponseBytes + 1)
        let headers = path == "/known-large" ? ["Content-Length": String(payload.count)] : [:]
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: payload)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Test func responseLimitsApplyWithAndWithoutContentLength() async throws {
    let configuration = UsageTransport.configuration()
    configuration.protocolClasses = [FixtureProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let transport = UsageTransport(session: session)
    let valid = try await transport.fetch(URLRequest(url: URL(string: "https://fixture.invalid/valid")!))
    #expect(valid == Data("{}".utf8))
    for path in ["known-large", "unknown-large", "unauthorized", "redirect"] {
        await #expect(throws: (any Error).self) {
            try await transport.fetch(URLRequest(url: URL(string: "https://fixture.invalid/\(path)")!))
        }
    }
}

@Test func excessiveOrMisleadingAPIFieldsAreRejected() throws {
    func data(total: Double = 10, date: Double = 1796083200, plan: String = "KIRO PRO") throws -> Data {
        try JSONSerialization.data(withJSONObject: ["subscriptionInfo": ["subscriptionTitle": plan],
            "nextDateReset": date, "usageBreakdownList": [["resourceType": "CREDIT", "currentUsage": total, "usageLimit": 1000]]])
    }
    #expect(throws: (any Error).self) { try UsageSnapshot.decode(Data(repeating: 32, count: 65_537)) }
    #expect(throws: (any Error).self) { try UsageSnapshot.decode(data(date: 1e100)) }
    #expect(throws: (any Error).self) { try UsageSnapshot.decode(data(total: 1e100)) }
    #expect(try UsageSnapshot.decode(data(plan: "KIRO\nForged message")).plan == "Kiro")
    #expect(try UsageSnapshot.decode(data(plan: "KIRO\u{202E}abc")).plan == "Kiro")
    #expect(try UsageSnapshot.decode(data(plan: String(repeating: "x", count: 1000))).plan.count == 64)
}

@Test func refreshStormIsThrottled() {
    var gate = RefreshGate()
    let start = ContinuousClock.now
    let first = gate.begin(at: start)
    #expect(first)
    for second in 0..<15 {
        let repeated = gate.begin(at: start.advanced(by: .seconds(second)))
        #expect(!repeated)
    }
    let afterCooldown = gate.begin(at: start.advanced(by: .seconds(15)))
    #expect(afterCooldown)
    let sameInstant = gate.begin(at: start.advanced(by: .seconds(15)))
    #expect(!sameInstant)
}

private func withDatabase(_ body: (URL, OpaquePointer) throws -> Void) throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("fixture.sqlite3")
    var db: OpaquePointer?
    guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else { throw TrackerError.notSignedIn }
    defer { sqlite3_close(db) }
    try body(url, db)
}

@Test func credentialsAreReadWithoutChangingTheDatabase() throws {
    try withDatabase { url, db in
        #expect(sqlite3_exec(db, "CREATE TABLE auth_kv(key TEXT PRIMARY KEY,value TEXT); CREATE TABLE state(key TEXT PRIMARY KEY,value TEXT); INSERT INTO auth_kv VALUES('kirocli:odic:token','{\"access_token\":\"fake-token\"}'); INSERT INTO state VALUES('api.codewhisperer.profile','{\"arn\":\"\(testARN)\"}');", nil, nil, nil) == SQLITE_OK)
        let before = try Data(contentsOf: url)
        let credentials = try CredentialStore.read(from: url)
        #expect(credentials.accessToken == "fake-token")
        #expect(credentials.profileARN == testARN)
        #expect(try Data(contentsOf: url) == before)
    }
}

@Test func oversizedCredentialsAndHostileViewsAreBounded() throws {
    try withDatabase { url, db in
        #expect(sqlite3_exec(db, "CREATE TABLE auth_kv(key TEXT PRIMARY KEY,value TEXT); INSERT INTO auth_kv VALUES('kirocli:odic:token',zeroblob(1000000));", nil, nil, nil) == SQLITE_OK)
        #expect(throws: (any Error).self) { try CredentialStore.read(from: url) }
    }
    try withDatabase { url, db in
        // A forged schema must not keep the process in an unbounded recursive query.
        #expect(sqlite3_exec(db, "CREATE VIEW auth_kv AS WITH RECURSIVE n(x) AS (VALUES(0) UNION ALL SELECT x+1 FROM n WHERE x<1000000000) SELECT 'kirocli:odic:token' AS key, sum(x) AS value FROM n;", nil, nil, nil) == SQLITE_OK)
        #expect(throws: (any Error).self) { try CredentialStore.read(from: url) }
    }
}
