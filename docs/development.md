# Development

[Documentation](README.md) | [Project overview](../README.md)

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
docs/                    Setup, usage, and development guides
scripts/
  build-app.sh             Build, sign, and optionally install a local app
  package-release.sh       Sign, notarize, and package a public release
```

`.build/`, `.swiftpm/`, and `dist/` are generated and ignored by Git.
