#!/bin/bash
# Explicit distribution workflow. Never uses the local ad-hoc signature for downloads.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool Keychain profile}"
if [[ "$SIGNING_IDENTITY" != "Developer ID Application:"* ]]; then
    echo "A Developer ID Application certificate is required." >&2
    exit 1
fi
swift test
BUILD_UNIVERSAL=1 bash scripts/build-app.sh
app="$PWD/dist/Kiro Tracker.app"
# Build the submission privately. Publish a release archive only after Apple accepts it.
staging=$(mktemp -d "$PWD/dist/.notarize.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto -c -k --keepParent "$app" "$staging/submission.zip"
xcrun notarytool submit "$staging/submission.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --strict "$app"
spctl --assess --type execute --verbose "$app"
ditto -c -k --keepParent "$app" "$staging/Kiro-Tracker-macOS.zip"
mv "$staging/Kiro-Tracker-macOS.zip" dist/Kiro-Tracker-macOS.zip
(cd dist && shasum -a 256 Kiro-Tracker-macOS.zip > Kiro-Tracker-macOS.zip.sha256)
echo "Verified release: $PWD/dist/Kiro-Tracker-macOS.zip"
