# Kiro Tracker

A lightweight native macOS menu-bar app that shows how much of your Kiro plan you have used. Click the Kiro logo and percentage to see your remaining credits, reset time, and overage usage.

Built with Swift, SwiftUI, and AppKit. No third-party package dependencies, background helpers, or separate tracker account are required. It reads the login already managed by **Kiro CLI**.

## Contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Install, update, or uninstall](#install-update-or-uninstall)
- [How it works](#how-it-works)
- [Configuration](#configuration)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Security and privacy](#security-and-privacy)
- [Build a public release](#build-a-public-release)
- [Contributing](#contributing)
- [License and acknowledgments](#license-and-acknowledgments)

## Requirements

| Requirement | Details |
| --- | --- |
| Operating system | macOS 14 Sonoma or later. Windows and Linux are not supported. |
| Hardware | Apple Silicon or Intel Mac. Universal builds contain both architectures; runtime testing so far has been on Apple Silicon. |
| Toolchain | Swift 6 or newer with a macOS SDK, supplied by a compatible Xcode or Command Line Tools installation. Full Xcode is required for universal builds and the release workflow. |
| Git | Required to clone the repository and contribute changes. |
| Kiro CLI | Installed and signed in to your own account. See the [Kiro CLI documentation](https://kiro.dev/docs/cli/). |
| Connectivity | Internet access to Kiro's usage service. US East (`us-east-1`) and Frankfurt (`eu-central-1`) profile regions are currently supported. |

Check your tools:

```sh
git --version
xcrun swift --version
kiro-cli --version
```

If Apple's developer tools are missing, install them with `xcode-select --install`, or install full Xcode and complete its first-launch setup. Check that the selected toolchain supplies Swift 6 or newer before continuing.

## Quick start

### 1. Clone the repository or your fork

Replace `OWNER` with the repository owner's account, or your own account if you created a fork. The URL below is a placeholder, not a published repository address.

```sh
git clone https://github.com/OWNER/kiro-tracker.git
cd kiro-tracker
```

To work from a fork, use the hosting service's **Fork** button first, then clone your fork using its actual clone URL. You do not need a fork just to build and run the app.

### 2. Sign in to Kiro CLI

Skip this if you are already signed in:

```sh
kiro-cli login
```

The tracker uses your own CLI session. You do not need to paste tokens, supply an API key, or edit any source files.

### 3. Test, build, and launch

Run these commands from the repository root:

```sh
swift test
bash scripts/build-app.sh
open "dist/Kiro Tracker.app"
```

The app appears in the **menu bar**, not the Dock. Click its logo or percentage to open the dropdown. The power button in the dropdown quits the app.

This launches the app directly from `dist/`; installation is optional. Quit any existing copy before launching a different build. Local builds are ad-hoc signed with hardened runtime and are not notarized public releases.

## Install, update, or uninstall

### Install for your user

Quit any running copy first:

```sh
INSTALL_DIR="$HOME/Applications" bash scripts/build-app.sh --install
open "$HOME/Applications/Kiro Tracker.app"
```

Without `INSTALL_DIR`, the installer uses the standard `/Applications` directory. Choose a directory you can write to; the script does not request administrator privileges.

The installer refuses to overwrite an existing app or replace a running instance.

### Update an existing installation

1. Quit Kiro Tracker using the dropdown's power button.
2. Pull the changes you want to install, then run `swift test` and `bash scripts/build-app.sh`.
3. In Finder, replace your installed `Kiro Tracker.app` with the new app from `dist/`.
4. Open the installed app again.

### Uninstall

Quit the app and move its installed `.app` bundle to Trash. If you only ran it from `dist/`, remove that bundle instead.

Kiro Tracker does not install launch agents or privileged helpers, and it does not enable launch at login. It does not maintain credential or usage-history files. macOS may retain its own application preferences or caches. Your Kiro CLI installation and login remain separate.

## How it works

The menu bar shows the percentage of **included monthly credits used**, rounded down. For example, 147.27 of 1,000 credits displays as `14%`.

| State | Dropdown |
| --- | --- |
| More than 250 credits remaining | Green included-usage bar |
| 250 or fewer credits remaining | Yellow included-usage bar |
| 50 or fewer credits remaining | Red included-usage bar |
| Actual overage usage | A second, blue bar showing overage used against Kiro's reported overage cap |

During overage, the menu bar also shows the extra credits used: `100% +25` means 25 overage credits. Enabling overage on the account alone does not activate this display. If Kiro omits the overage cap, the dropdown shows a blue marker and exact count instead of inventing a percentage.

Usage refreshes:

- At launch and approximately every five minutes, with up to 30 seconds of scheduling tolerance to reduce wakeups.
- When the Mac wakes or you open the dropdown.
- When you click the refresh button.

Requests never overlap, and all refresh triggers share a 15-second cooldown. The last-updated time appears at the bottom of the dropdown.

A failed network refresh retains the last reading and marks it with a warning and `!` in the menu bar. Sign-out, authentication failure, an invalid database path, or an unsupported account region clears the reading.

**Known limitation:** non-empty bonus-credit pools are reported as unsupported because this API does not reliably separate them from included-plan usage. The app uses Kiro's private usage API, which may change independently of this project.

## Configuration

### Database location

By default, the app asks macOS for the current user's Application Support directory and reads `kiro-cli/data.sqlite3` beneath it. This normally resolves to:

```text
~/Library/Application Support/kiro-cli/data.sqlite3
```

There are no developer-specific usernames or checkout paths in the configuration. Each user must sign in through their own Kiro CLI installation.

For a custom location, precedence is:

1. `--database PATH`
2. `KIRO_TRACKER_DATABASE_PATH`
3. The current user's standard macOS location

Absolute paths and `~/` are supported. Invalid overrides fail explicitly rather than silently falling back to another account.

```sh
# Check a custom database without launching the GUI.
swift run KiroTracker --check --database "$HOME/custom-kiro/data.sqlite3"

# Equivalent environment-variable override.
KIRO_TRACKER_DATABASE_PATH="$HOME/custom-kiro/data.sqlite3" \
  swift run KiroTracker --check
```

For an installed app, quit it first, then launch with the override:

```sh
open -a "Kiro Tracker" --args --database "$HOME/custom-kiro/data.sqlite3"
```

This override applies to that launch; it is not saved as a preference. Finder launches do not inherit shell environment variables. The standard location requires no configuration.

### Build and release settings

| Variable | Purpose | Default |
| --- | --- | --- |
| `INSTALL_DIR` | Absolute destination directory for `--install` | `/Applications` |
| `BUILD_UNIVERSAL` | Set to `1` to build Apple Silicon and Intel slices | Current Mac architecture only |
| `SIGNING_IDENTITY` | Your `Developer ID Application: …` identity | Local ad-hoc signing |
| `NOTARY_PROFILE` | Existing `notarytool` Keychain profile for release notarization | None; required by the release script |

Build scripts resolve the repository relative to their own location, so they can be invoked from another working directory. AWS usage endpoints are intentionally fixed to known service hosts; a custom database cannot redirect credentials to an arbitrary server.

## Development

Run the app directly through SwiftPM:

```sh
swift run KiroTracker
```

The terminal stays attached until you quit the app. Quit it before starting another copy or rebuilding an installed bundle.

Useful commands:

```sh
# Run the regression tests using fabricated credentials and temporary databases.
swift test

# Make one real usage request, print the result, and exit.
swift run KiroTracker --check

# Show command-line options.
swift run KiroTracker --help

# Build a release app containing both supported architectures.
BUILD_UNIVERSAL=1 bash scripts/build-app.sh
```

Debug builds also provide:

```sh
# Render synthetic green/yellow/red/overage dropdowns to PNGs.
swift run KiroTracker --render-previews

# Briefly open the dropdown, print its menu-bar gap, verify view release, and exit.
swift run KiroTracker --inspect-layout
```

The preview command prints the unique output directory under the current user's system temporary folder. Debug-only helpers are excluded from release builds.

### Project structure

```text
Sources/
  KiroTracker/              Menu-bar lifecycle, dropdown UI, and logo
  KiroTrackerCore/          Credentials, paths, networking, usage model, throttling
Tests/
  KiroTrackerCoreTests/     Usage, security, and portability regression tests
scripts/
  build-app.sh             Build, sign, and optionally install a local app
  package-release.sh       Sign, notarize, and package a public release
SECURITY.md                Security model, limitations, and performance measurements
THIRD_PARTY_NOTICES.txt    Attribution and license for the logo asset
```

`.build/`, `.swiftpm/`, and `dist/` are generated and ignored by Git.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Build reports an unsupported Swift tools version | Run `xcrun swift --version`; select or install a toolchain with Swift 6 or newer. |
| Universal build fails with only Command Line Tools installed | Install full Xcode, complete first-launch setup, and select it as the active developer directory. A normal native build does not require the universal build path. |
| No Dock icon appears | This is a menu-bar app. Look for the Kiro logo and percentage in the menu bar. Use `swift run KiroTracker --check` to diagnose usage access independently of the UI. |
| “Sign in with kiro-cli login” | Sign in with your own CLI account. Confirm that you are using the correct database location. |
| Session expired | Use Kiro CLI to renew the session, or run `kiro-cli login`. Wait for the 15-second cooldown, then refresh. The tracker never renews or overwrites CLI tokens itself. |
| An `!` appears beside the percentage | Open the dropdown for the error. Check connectivity and the last-updated time; the displayed reading may be stale. |
| Unsupported profile region or bonus credits | These are current integration limitations, not values you can fix by editing the percentage. See [How it works](#how-it-works). |
| Installer refuses to overwrite the app | Quit the existing instance, build again, and replace the old bundle in Finder as described under [Update](#update-an-existing-installation). |
| macOS blocks a downloaded build | Use a properly Developer ID-signed, notarized release, or review and build the source yourself. Do not disable Gatekeeper to install it. |

When reporting a problem, include macOS, Swift, and Kiro CLI versions, the relevant error, and steps to reproduce. **Do not attach the Kiro database, access tokens, refresh tokens, or raw authentication logs.**

## Security and privacy

The tracker reads Kiro credentials **read-only** and sends the access token only to the supported HTTPS Kiro usage endpoint. It blocks redirects, bounds response and credential sizes, and disables network caches, cookies, and credential persistence.

It does not send telemetry, start chats, modify Kiro settings, store tokens, or listen on a local server. There are no third-party runtime packages to install.

The app enables hardened runtime but is **not sandboxed**. Local builds are **not notarized**, and the source audit is not a guarantee against every vulnerability. Read [SECURITY.md](SECURITY.md) for the threat boundaries, verification performed, and measured CPU/memory use.

## Build a public release

This workflow is for maintainers distributing downloads. It requires:

- Full Xcode.
- Your own **Developer ID Application** certificate and private key in Keychain. An Apple Distribution certificate is not a substitute.
- A configured `notarytool` Keychain profile. See [Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and `xcrun notarytool store-credentials --help` for setup.

Replace the example identity and profile with your own values:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-notary-profile' \
  bash scripts/package-release.sh
```

The script runs tests, builds a universal app, signs it with a secure timestamp and hardened runtime, **uploads it to Apple's notarization service**, staples the accepted ticket, and verifies the signature and Gatekeeper acceptance. It only creates the final download archive after those checks succeed:

```text
dist/Kiro-Tracker-macOS.zip
dist/Kiro-Tracker-macOS.zip.sha256
```

Missing signing inputs cause an early failure. No account, token, signing identity, or notary credential is embedded as app configuration. This project has not yet completed Developer ID signing/notarization; do not describe the local ad-hoc build as a verified public release. The Intel slice cross-compiles, but testing on Intel hardware and macOS 14 remains part of release validation.

## Contributing

1. Fork the repository on its hosting service and clone your fork.
2. Create a focused branch, for example `git switch -c fix/usage-display`.
3. Make the change. Add regression tests for behavioral or security changes.
4. Run `swift test` and `bash scripts/build-app.sh`. Check the dropdown if the UI changed.
5. Open a pull request explaining the problem, the resulting behavior, and how you verified it.

Keep credentials and personal paths out of source, fixtures, screenshots, and reports. For a suspected security issue, contact the repository maintainer privately through the hosting service before publishing sensitive details.

## License and acknowledgments

A project license for the original Kiro Tracker code has not yet been selected. No project-wide license grant is implied by the third-party asset notice.

The Kiro logo paths are adapted from CrossUsage and include their MIT notice in [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt). Kiro's name and logo belong to their respective owner; this project is not affiliated with or endorsed by Kiro or AWS.

Protocol references: [CodexBar's Kiro integration notes](https://github.com/steipete/CodexBar/blob/main/docs/kiro.md) and [Kiro billing documentation](https://kiro.dev/docs/billing/). The tracker implementation is independent.
