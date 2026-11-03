# Security and performance

Reviewed locally on November 3, 2026. This is a source audit and regression-test pass, not an independent penetration test or a guarantee that all vulnerabilities have been found.

## Data access and trust boundaries

- Reads only the selected Kiro CLI SQLite authentication/profile records. The default location is resolved through macOS for the current user; custom locations are explicit. The connection is read-only and query-only, both records are read in one transaction, schema trust is disabled, and SQL statements are fixed. No history or conversation tables are queried.
- Requires a regular database file, rejecting pipes/devices/directories before opening SQLite. Bounds credential records to 64 KiB and tokens to 16 KiB. Database lock waits are limited to 100 ms and a SQLite progress callback aborts expensive or hostile queries after 100,000 VM instructions.
- Profile ARNs must match the supported service, region, account, and resource shape. Credentials can only select the fixed HTTPS US East or Frankfurt Kiro endpoint. Tokens containing whitespace/control characters are rejected.
- Rejects every HTTP redirect, including same-host redirects. Uses the system TLS trust checks with no certificate bypass or ATS exceptions. Credential storage, cookies, and URL caches are disabled. A resource request times out after 20 seconds; responses are streamed and rejected above 64 KiB, including bodies with missing Content-Length. Foundation's own transient networking buffers are outside that parser limit.
- Rejects malformed amounts and reset dates; bounds plan labels and strips misleading control-format labels. Authentication failures and unsupported account regions clear the previous reading rather than continuing to show another account's usage.
- Does not write Kiro credentials, refresh tokens, usage history, or telemetry. It does not run shell commands, start chats, listen on ports, install privileged helpers, or add launch agents. Tokens necessarily exist briefly in process memory while a request is made; Kiro CLI retains responsibility for renewing them.

The app is **not sandboxed** because it directly reads another app's authentication database. Hardened runtime is enabled without exceptions, but this does not protect against every same-user compromise, root access, or OS/framework vulnerability. A compromised process could access the user's files. Do not treat this as a credential vault. The usage endpoint is a private Kiro contract and may change.

## Distribution

Local builds are ad-hoc signed with hardened runtime; they are not a verified public download. No Developer ID Application certificate was available during this audit, and no notarization was attempted.

`scripts/package-release.sh` requires a Developer ID Application identity and a notarytool Keychain profile. It tests, builds both arm64 and x86_64, signs and timestamps a freshly assembled bundle, submits it to Apple's notary service, staples and validates the ticket, and checks Gatekeeper acceptance before producing the release ZIP and checksum. A missing identity/profile fails before upload. No Apple credentials, Kiro tokens, or developer-specific filesystem locations are bundled as configuration.

The current binary was run on Apple Silicon. The Intel slice was cross-compiled; execution on Intel hardware and macOS 14 still needs release testing. Keep macOS and Xcode patched, review changes before signing, and never distribute a build that failed signature/notarization checks. Apple's requirements: [Developer ID](https://developer.apple.com/developer-id/) and [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Resource usage

- One request at a time; manual/open/wake triggers share a monotonic 15-second cooldown, including failed attempts.
- Background refresh approximately every five minutes, with 30-second tolerance for timer coalescing. No tight polling loop, filesystem watcher, or subprocess.
- Dropdown content is constructed on open and released on close. The last-updated label is static, so no hidden one-second/30-second UI timer runs.
- Network, SQLite, parsing, and credential reads run off the UI actor. Errors stop that attempt; there is no immediate retry loop.

Observed on the development Mac after hardening, with the dropdown closed: seven samples over 30 seconds showed 0.0% CPU, zero idle wakeups, and approximately 16 MB physical footprint (`top`). Resident memory including mapped/shared pages was about 46 MB (`ps`). A separate live `--check` completed in 0.32 seconds wall time and 0.02 seconds CPU time. These short measurements are not a long-duration leak test, battery benchmark, or guarantee for every system. Opening the UI and fetching usage will briefly use additional resources.

## Verification

Regression tests cover credit thresholds, overage separation, invalid and oversized data, token/header injection, arbitrary endpoint attempts, redirect rejection, response limits with/without Content-Length, disabled persistence, refresh throttling, unchanged credential database bytes, a hostile recursive SQLite view, and custom-location precedence/validation. Tests use fabricated credentials and temporary databases, not the developer's account. Live checks are explicit via `--check`.

The native debug layout check also verifies that closing the dropdown releases its hosting view. Build scripts are syntax-checked, the universal binary is inspected, and hardened-runtime signatures are verified locally. Public signing/notarization requires the release credentials described above.
