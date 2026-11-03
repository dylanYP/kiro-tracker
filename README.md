# Kiro Tracker

A lightweight macOS menu-bar app for tracking your Kiro CLI usage. It shows the percentage used beside the Kiro logo, with a dropdown for remaining credits, reset time, and overage usage.

The usage bar turns yellow at 250 credits remaining and red at 50. Overage appears in a separate blue bar and in the menu-bar label. The app uses your existing Kiro CLI login and refreshes about every five minutes.

## Run locally

You need macOS 14 or later, Git, Swift 6 or newer with a macOS SDK, and [Kiro CLI](https://kiro.dev/docs/cli/) installed. Xcode or compatible Command Line Tools provide the Swift toolchain.

Sign in with `kiro-cli login` if you have not already, then run:

```sh
git clone https://github.com/dylanYP/kiro-tracker.git
cd kiro-tracker
swift test
bash scripts/build-app.sh
open "dist/Kiro Tracker.app"
```

To use a fork, replace the clone URL with your fork's URL.

Look for the Kiro logo and percentage in the menu bar. Click to open the dropdown; its power button quits the app. Quit any existing copy before launching another build.

## Documentation

See the [docs folder](docs/README.md) for installation, configuration, development, troubleshooting, and release instructions.
