import Foundation
import Testing
@testable import KiroTrackerCore

@Test func standardLocationUsesProvidedUserSupportDirectory() throws {
    let support = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let resolved = try DatabaseLocation.resolve(arguments: [], environment: [:], applicationSupportURL: support)
    #expect(resolved == support.appendingPathComponent("kiro-cli/data.sqlite3"))
}

@Test func explicitPathOverridesEnvironmentAndSupportsSpaces() throws {
    let resolved = try DatabaseLocation.resolve(arguments: ["app", "--database", "/custom data/cli.sqlite3"],
        environment: ["KIRO_TRACKER_DATABASE_PATH": "/other/data.sqlite3"])
    #expect(resolved.path == "/custom data/cli.sqlite3")
}

@Test func environmentPathExpandsCurrentUsersHome() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let resolved = try DatabaseLocation.resolve(arguments: [],
        environment: ["KIRO_TRACKER_DATABASE_PATH": "~/custom/data.sqlite3"], homeURL: home)
    #expect(resolved == home.appendingPathComponent("custom/data.sqlite3"))
}

@Test func invalidCustomPathNeverSilentlyFallsBack() {
    for path in ["", "relative.sqlite3", "https://attacker.invalid/db", "/bad\npath"] {
        #expect(throws: (any Error).self) {
            try DatabaseLocation.resolve(arguments: [], environment: ["KIRO_TRACKER_DATABASE_PATH": path])
        }
    }
    for args in [["--database"], ["--database", "--check"], ["--database", "/a", "--database", "/b"]] {
        #expect(throws: (any Error).self) { try DatabaseLocation.resolve(arguments: args, environment: [:]) }
    }
}
