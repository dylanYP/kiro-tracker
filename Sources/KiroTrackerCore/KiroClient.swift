import Foundation

public actor KiroClient {
    private let databaseURL: URL?
    private let transport: UsageTransport

    public init(databaseURL: URL? = nil) {
        self.databaseURL = databaseURL
        self.transport = UsageTransport()
    }

    public func fetch() async throws -> UsageSnapshot {
        try Task.checkCancellation()
        // Pick up any token changes made by Kiro CLI.
        let credentials = try CredentialStore.read(from: databaseURL ?? DatabaseLocation.resolve())
        let request = try Self.request(token: credentials.accessToken, profileARN: credentials.profileARN)
        return try UsageSnapshot.decode(await transport.fetch(request))
    }

    static func request(token: String, profileARN: String) throws -> URLRequest {
        // Only send credentials to the supported Kiro regions.
        guard profileARN.utf8.count <= 256,
              profileARN.range(of: #"\Aarn:aws:codewhisperer:(us-east-1|eu-central-1):[0-9]{12}:profile/[A-Za-z0-9_-]{1,128}\z"#,
                               options: .regularExpression) != nil else { throw TrackerError.unsupportedRegion }
        guard !token.isEmpty, token.utf8.count <= 16_384,
              token.utf8.allSatisfy({ (33...126).contains($0) }) else { throw TrackerError.notSignedIn }
        let region = profileARN.split(separator: ":")[3]
        let endpoint = region == "us-east-1"
            ? "https://codewhisperer.us-east-1.amazonaws.com/"
            : "https://q.eu-central-1.amazonaws.com/"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-amz-json-1.0", forHTTPHeaderField: "Content-Type")
        request.setValue("AmazonCodeWhispererService.GetUsageLimits", forHTTPHeaderField: "X-Amz-Target")
        request.setValue("KiroTracker/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["profileArn": profileARN])
        return request
    }
}
