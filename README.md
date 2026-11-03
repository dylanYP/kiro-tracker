# Kiro Tracker

A small native macOS menu-bar app for your Kiro CLI account. SwiftUI + AppKit, with no third-party dependencies. Requires macOS 14 or newer and an existing Kiro CLI login.

The menu bar shows the percentage of monthly included credits used (rounded down). Click it for exact credit counts and a progress bar:

- Green above 250 credits remaining.
- Yellow at 250 or fewer credits remaining.
- Red at 50 or fewer credits remaining.
- Actual overage adds a separate blue bar against the overage cap reported by Kiro. The menu reads, for example, `100% +25` for 25 overage credits. Merely enabling overage does not display this bar.

Usage refreshes every five minutes, on wake, on opening the panel, and via the refresh button. Failed refreshes preserve the last result with an explicit warning and `!` in the menu bar. No usage is shown as zero just because an API request failed.

## Build and run

```sh
swift test
bash scripts/build-app.sh --install
open '/Applications/Kiro Tracker.app'
```

Build without installation: `bash scripts/build-app.sh`. The app bundle is in `dist/`.
Check real connectivity without opening the GUI: `.build/release/KiroTracker --check`.
Render synthetic green/yellow/red/overage UI states: `swift run KiroTracker --render-previews` (debug builds only; writes PNGs under `/tmp/kiro-tracker-previews`).

## Authentication and data

Reads the existing `~/Library/Application Support/kiro-cli/data.sqlite3` database **read-only**. Tokens stay in memory and are sent only to the AWS Kiro usage endpoint for your profile region. Kiro CLI owns token renewal; the tracker rereads its token on each refresh. If your session expires, use Kiro CLI to renew it (or `kiro-cli login`) and refresh the tracker. The app never starts a chat, modifies Kiro settings, stores credentials, or sends telemetry.

Uses the private `AmazonCodeWhispererService.GetUsageLimits` contract, which may change. US East and Frankfurt profiles are supported. API current usage includes overage; the tracker subtracts it from the main bar to avoid double-counting. Non-empty bonus pools are explicitly reported as unsupported because their relationship to plan usage is ambiguous. Missing overage caps show a blue marker with an exact count rather than an invented percentage.

Protocol references: [CodexBar's Kiro integration notes](https://github.com/steipete/CodexBar/blob/main/docs/kiro.md) and [Kiro billing documentation](https://kiro.dev/docs/billing/). Implementation is independent.

The local build is ad-hoc signed, not notarized for distribution. It does not install a startup agent or enable launch at login. To uninstall, quit via the panel's power button and remove `/Applications/Kiro Tracker.app`; the tracker maintains no credential or usage files. macOS may retain its own application caches/preferences.
