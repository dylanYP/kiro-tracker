# Setup and installation

[Documentation](README.md) | [Project overview](../README.md)

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
