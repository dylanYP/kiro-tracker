# Usage

[Documentation](README.md) | [Project overview](../README.md)

## Reading the menu bar

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

## Privacy

The tracker reads Kiro credentials **read-only** and sends the access token only to the supported HTTPS Kiro usage endpoint. It blocks redirects, bounds response and credential sizes, and disables network caches, cookies, and credential persistence.

It does not send telemetry, start chats, modify Kiro settings, store tokens, or listen on a local server. There are no third-party runtime packages to install.

The app enables hardened runtime but is **not sandboxed**. Local builds are **not notarized**, and the source audit is not a guarantee against every vulnerability.
