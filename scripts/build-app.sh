#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${SIGNING_IDENTITY:-}" && "$SIGNING_IDENTITY" != "Developer ID Application:"* ]]; then
    echo "SIGNING_IDENTITY must be a Developer ID Application identity." >&2
    exit 1
fi
build_arguments=(-c release)
if [[ "${BUILD_UNIVERSAL:-0}" == "1" ]]; then
    build_arguments+=(--arch arm64 --arch x86_64)
fi
swift build "${build_arguments[@]}"
binary_directory=$(swift build "${build_arguments[@]}" --show-bin-path)
# Start with a clean bundle to leave out old build files.
mkdir -p dist
staging=$(mktemp -d "$PWD/dist/.bundle.XXXXXX")
trap 'rm -rf "$staging"' EXIT
app="$staging/Kiro Tracker.app"
mkdir -p "$app/Contents/MacOS"
mkdir -p "$app/Contents/Resources"
cp THIRD_PARTY_NOTICES.txt "$app/Contents/Resources/"
cp "$binary_directory/KiroTracker" "$app/Contents/MacOS/KiroTracker"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>KiroTracker</string>
  <key>CFBundleIdentifier</key><string>dev.kirotracker.app</string>
  <key>CFBundleName</key><string>Kiro Tracker</string>
  <key>CFBundleDisplayName</key><string>Kiro Tracker</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app"
else
    codesign --force --options runtime --sign - "$app"
fi
codesign --verify --strict "$app"
output="$PWD/dist/Kiro Tracker.app"
rm -rf "$output"
mv "$app" "$output"
app="$output"
echo "Built: $app"
if [[ "${1:-}" == "--install" ]]; then
    if pgrep -x KiroTracker >/dev/null; then
        echo "Quit Kiro Tracker before replacing its installed bundle." >&2
        exit 1
    fi
    install_directory="${INSTALL_DIR:-/Applications}"
    if [[ "$install_directory" != /* ]]; then
        echo "INSTALL_DIR must be an absolute path." >&2
        exit 1
    fi
    mkdir -p "$install_directory"
    destination="$install_directory/Kiro Tracker.app"
    if [[ -e "$destination" || -L "$destination" ]]; then
        echo "An installed bundle already exists; remove it before using --install." >&2
        exit 1
    fi
    ditto "$app" "$destination"
    echo "Installed: $destination"
fi
