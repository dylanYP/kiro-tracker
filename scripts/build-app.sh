#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
app="$PWD/dist/Kiro Tracker.app"
mkdir -p "$app/Contents/MacOS"
mkdir -p "$app/Contents/Resources"
cp THIRD_PARTY_NOTICES.txt "$app/Contents/Resources/"
cp .build/release/KiroTracker "$app/Contents/MacOS/KiroTracker"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>KiroTracker</string>
  <key>CFBundleIdentifier</key><string>dev.dperalta.kiro-tracker</string>
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
codesign --force --sign - "$app"
echo "Built: $app"
if [[ "${1:-}" == "--install" ]]; then
    ditto "$app" "/Applications/Kiro Tracker.app"
    echo "Installed: /Applications/Kiro Tracker.app"
fi
