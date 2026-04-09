#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/sign-and-notarize-app.sh "Releases/macOS14-Universal/IPSW Downloader.app"
#
# Required:
#   1) A valid "Developer ID Application" certificate installed in Keychain.
#   2) notarytool profile configured once:
#      xcrun notarytool store-credentials "AC_NOTARY" \
#        --apple-id "you@example.com" \
#        --team-id "YOUR_TEAM_ID" \
#        --password "app-specific-password"
#
# Optional env vars:
#   SIGN_IDENTITY   -> override signing identity (default: first Developer ID Application identity)
#   NOTARY_PROFILE  -> notarytool keychain profile (default: AC_NOTARY)

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-app-bundle>"
  exit 1
fi

APP_PATH="$1"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_NOTARY}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning | awk -F\" '/Developer ID Application/ {print $2; exit}')"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "No Developer ID Application identity found in Keychain."
  exit 1
fi

APP_DIR="$(cd "$(dirname "$APP_PATH")" && pwd)"
APP_NAME="$(basename "$APP_PATH")"
ZIP_PATH="$APP_DIR/${APP_NAME%.app}.zip"

echo "Signing app: $APP_PATH"
echo "Identity: $SIGN_IDENTITY"

# Sign nested content and the app bundle with Hardened Runtime + timestamp.
codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_PATH"

# Verify local signature integrity before notarization.
codesign --verify --strict --deep --verbose=2 "$APP_PATH"

echo "Packaging for notarization: $ZIP_PATH"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Submitting to Apple notary service (profile: $NOTARY_PROFILE)"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Stapling notarization ticket"
xcrun stapler staple "$APP_PATH"

echo "Final Gatekeeper assessment"
spctl -a -vv "$APP_PATH"

echo "Done: app is signed, notarized, and stapled."
