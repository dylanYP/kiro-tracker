# Configuration

[Documentation](README.md) | [Project overview](../README.md)

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
