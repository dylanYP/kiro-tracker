import Foundation
import SQLite3

struct Credentials {
    let accessToken: String
    let profileARN: String
}

enum CredentialStore {
    static func read(from url: URL) throws -> Credentials {
        let resolved = url.resolvingSymlinksInPath()
        guard (try? resolved.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
            throw TrackerError.notSignedIn
        }
        var database: OpaquePointer?
        guard sqlite3_open_v2(resolved.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }
            throw TrackerError.notSignedIn
        }
        defer { sqlite3_close(database) }
        // Be a cheap, read-only guest in Kiro's database, even if its schema is corrupt.
        sqlite3_busy_timeout(database, 100)
        sqlite3_limit(database, SQLITE_LIMIT_LENGTH, 64 * 1024)
        sqlite3_limit(database, SQLITE_LIMIT_SQL_LENGTH, 1024)
        // Apple's SQLite does not expose extension loading; never enable it.
        // Prevent malicious views or huge scans from monopolizing the actor/CPU.
        sqlite3_progress_handler(database, 100_000, { _ in 1 }, nil)
        guard sqlite3_exec(database, "PRAGMA trusted_schema=OFF; PRAGMA query_only=ON; BEGIN;", nil, nil, nil) == SQLITE_OK else {
            throw TrackerError.notSignedIn
        }
        defer { sqlite3_exec(database, "ROLLBACK;", nil, nil, nil) }
        func readValue(_ sql: String) throws -> Data {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw TrackerError.notSignedIn
            }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let bytes = sqlite3_column_blob(statement, 0) else { throw TrackerError.notSignedIn }
            let count = Int(sqlite3_column_bytes(statement, 0))
            guard count > 0, count <= 64 * 1024 else { throw TrackerError.notSignedIn }
            return Data(bytes: bytes, count: count)
        }
        struct Token: Decodable { let access_token: String }
        struct Profile: Decodable { let arn: String }
        do {
            let decoder = JSONDecoder()
            let token = try decoder.decode(Token.self, from: readValue("SELECT value FROM auth_kv WHERE key = 'kirocli:odic:token' LIMIT 1"))
            let profile = try decoder.decode(Profile.self, from: readValue("SELECT value FROM state WHERE key = 'api.codewhisperer.profile' LIMIT 1"))
            return Credentials(accessToken: token.access_token, profileARN: profile.arn)
        } catch { throw TrackerError.notSignedIn }
    }
}
