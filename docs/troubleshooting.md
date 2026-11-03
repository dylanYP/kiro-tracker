# Troubleshooting

[Documentation](README.md) | [Project overview](../README.md)

| Problem | What to check |
| --- | --- |
| Build reports an unsupported Swift tools version | Run `xcrun swift --version`; select or install a toolchain with Swift 6 or newer. |
| Universal build fails with only Command Line Tools installed | Install full Xcode, complete first-launch setup, and select it as the active developer directory. A normal native build does not require the universal build path. |
| No Dock icon appears | This is a menu-bar app. Look for the Kiro logo and percentage in the menu bar. Use `swift run KiroTracker --check` to diagnose usage access independently of the UI. |
| “Sign in with kiro-cli login” | Sign in with your own CLI account. Confirm that you are using the correct database location. |
| Session expired | Use Kiro CLI to renew the session, or run `kiro-cli login`. Wait for the 15-second cooldown, then refresh. The tracker never renews or overwrites CLI tokens itself. |
| An `!` appears beside the percentage | Open the dropdown for the error. Check connectivity and the last-updated time; the displayed reading may be stale. |
| Unsupported profile region or bonus credits | These are current integration limitations, not values you can fix by editing the percentage. See [How it works](usage.md). |
| Installer refuses to overwrite the app | Quit the existing instance, build again, and replace the old bundle in Finder as described under [Update](setup.md#update-an-existing-installation). |
| macOS blocks a downloaded build | Use a properly Developer ID-signed, notarized release, or review and build the source yourself. Do not disable Gatekeeper to install it. |

When reporting a problem, include macOS, Swift, and Kiro CLI versions, the relevant error, and steps to reproduce. **Do not attach the Kiro database, access tokens, refresh tokens, or raw authentication logs.**
