# Release builds

[Documentation](README.md) | [Project overview](../README.md)

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
