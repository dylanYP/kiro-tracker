import Foundation

enum DatabaseLocation {
    /// Explicit flag > environment override > the current user's standard macOS location.
    /// Invalid overrides fail closed rather than accidentally reading a different account.
    static func resolve(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        applicationSupportURL: URL? = nil,
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> URL {
        let flags = arguments.indices.filter { arguments[$0] == "--database" }
        guard flags.count <= 1 else { throw TrackerError.invalidDatabasePath }
        let override: String?
        if let index = flags.first {
            guard index + 1 < arguments.count else { throw TrackerError.invalidDatabasePath }
            override = arguments[index + 1]
        } else {
            override = environment["KIRO_TRACKER_DATABASE_PATH"]
        }
        if let override {
            guard !override.isEmpty, override.utf8.count <= 4096,
                  !override.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw TrackerError.invalidDatabasePath
            }
            if override.hasPrefix("~/") {
                return homeURL.appendingPathComponent(String(override.dropFirst(2))).standardizedFileURL
            }
            guard override.hasPrefix("/") else { throw TrackerError.invalidDatabasePath }
            return URL(fileURLWithPath: override).standardizedFileURL
        }
        guard let support = applicationSupportURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { throw TrackerError.notSignedIn }
        return support.appendingPathComponent("kiro-cli", isDirectory: true).appendingPathComponent("data.sqlite3")
    }
}
