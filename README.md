# Kiro Tracker

A small native macOS menu-bar app for your Kiro CLI account. SwiftUI + AppKit, with no third-party dependencies. Requires macOS 14 or newer and an existing Kiro CLI login.

The menu bar shows the percentage of monthly included credits used (rounded down). Click it for exact credit counts and a progress bar:

- Green above 250 credits remaining.
- Yellow at 250 or fewer credits remaining.
- Red at 50 or fewer credits remaining.
- Actual overage adds a separate blue bar against the overage cap reported by Kiro. The menu reads, for example, `100% +25` for 25 overage credits. Merely enabling overage does not display this bar.

Usage refreshes approximately every five minutes (up to 30 seconds of scheduling tolerance to reduce wakeups), on wake, on opening the panel, and via the refresh button. Requests never overlap and are throttled to at most one attempt every 15 seconds. Failed network refreshes preserve the last result with an explicit warning and `!` in the menu bar; sign-out, authentication failure, or an unsupported account region clears it. No usage is shown as zero just because an API request failed.

## Build and run

```sh
swift test
bash scripts/build-app.sh --install
open '/Applications/Kiro Tracker.app'
```

Build without installation: `bash scripts/build-app.sh`. The app bundle is in `dist/`.
For an existing installation, quit the app and replace its bundle with the new build; `--install` refuses to overwrite a running or existing installation. Set `BUILD_UNIVERSAL=1` to build both Apple Silicon and Intel slices. Full Xcode is required for the universal build; the native SwiftPM build needs a macOS SDK and Swift 6 or newer.
Check real connectivity without opening the GUI: `.build/release/KiroTracker --check`.
Render synthetic green/yellow/red/overage UI states: `swift run KiroTracker --render-previews` (debug builds only; prints the unique directory created in the current user's system temporary folder).

## Other developers and custom locations

Nothing is tied to the original developer's username, checkout directory, account, signing team, or Kiro profile. The default database location comes from macOS's Application Support directory for the current user. Each developer signs in with their own Kiro CLI account.

Override the database with `--database PATH` or `KIRO_TRACKER_DATABASE_PATH`. The flag takes precedence; absolute paths and `~/` are supported. Invalid overrides fail rather than silently reading the default account. No custom credential is copied into the app.

```sh
swift run KiroTracker --check --database "$HOME/custom-kiro/data.sqlite3"
KIRO_TRACKER_DATABASE_PATH="$HOME/custom-kiro/data.sqlite3" swift run KiroTracker --check
```

For a downloaded app, quit it first and use `open -a 'Kiro Tracker' --args --database "$HOME/custom-kiro/data.sqlite3"`. Finder launches do not inherit shell variables; the standard Kiro location works without configuration.

Choose an install directory without editing a script:

```sh
INSTALL_DIR="$HOME/Applications" bash scripts/build-app.sh --install
open "$HOME/Applications/Kiro Tracker.app"
```

`INSTALL_DIR` defaults to the standard `/Applications` location. Source and build paths are resolved relative to the script, not the shell's working directory. AWS API hosts are deliberately fixed to known Kiro service endpoints; custom database locations cannot redirect credentials elsewhere.

## Authentication and data

Reads the existing `~/Library/Application Support/kiro-cli/data.sqlite3` database **read-only**. Tokens stay in memory and are sent only to the AWS Kiro usage endpoint for your profile region. Kiro CLI owns token renewal; the tracker rereads its token on each refresh. If your session expires, use Kiro CLI to renew it (or `kiro-cli login`) and refresh the tracker. The app never starts a chat, modifies Kiro settings, stores credentials, or sends telemetry.

Uses the private `AmazonCodeWhispererService.GetUsageLimits` contract, which may change. US East and Frankfurt profiles are supported. API current usage includes overage; the tracker subtracts it from the main bar to avoid double-counting. Non-empty bonus pools are explicitly reported as unsupported because their relationship to plan usage is ambiguous. Missing overage caps show a blue marker with an exact count rather than an invented percentage.

Protocol references: [CodexBar's Kiro integration notes](https://github.com/steipete/CodexBar/blob/main/docs/kiro.md) and [Kiro billing documentation](https://kiro.dev/docs/billing/). Implementation is independent.

The local build enables hardened runtime but is ad-hoc signed, not notarized for distribution. It does not install a startup agent or enable launch at login. To uninstall, quit via the panel's power button and remove `/Applications/Kiro Tracker.app`; the tracker maintains no credential or usage files. macOS may retain its own application caches/preferences.

## Distribution

Do not distribute the local ad-hoc build as a trusted download. Use your own **Developer ID Application** certificate and an existing `notarytool` Keychain profile:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-notary-profile' bash scripts/package-release.sh
```

This explicit command builds a universal binary, signs with hardened runtime, uploads the app to Apple's notarization service, staples the ticket, verifies Gatekeeper acceptance, then creates a ZIP and SHA-256 checksum. No credentials are embedded in the bundle. The workflow fails before building/uploading if signing inputs are absent. An Apple Distribution certificate is not a substitute. No notarization was performed during local development.

See [SECURITY.md](SECURITY.md) for the security model, audit limits, and performance measurements.
