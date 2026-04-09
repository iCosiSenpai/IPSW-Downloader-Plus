#!/usr/bin/env bash
set -euo pipefail

# build-test-archive.sh — Build, test, and archive IPSW Downloader Plus
#
# Usage:
#   ./scripts/build-test-archive.sh            # Build + test + archive
#   ./scripts/build-test-archive.sh --skip-test # Skip tests, just build + archive
#
# Outputs:
#   Releases/IPSW Downloader Plus.app   (universal binary, macOS 14+)
#
# After this script succeeds, run:
#   ./scripts/sign-and-notarize-releases.sh
# to sign and notarize the archive for distribution.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/IPSW Downloader Plus.xcodeproj"
SCHEME="IPSW Downloader Plus"
CONFIGURATION="Release"
DESTINATION="platform=macOS"
ARCHIVE_DIR="$ROOT_DIR/Releases"
APP_NAME="IPSW Downloader Plus"

SKIP_TESTS=false
for arg in "$@"; do
    case "$arg" in
        --skip-test|--skip-tests) SKIP_TESTS=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

echo "========================================"
echo " IPSW Downloader Plus — Build Pipeline"
echo "========================================"
echo ""

# ── Step 1: Run tests ──
if [[ "$SKIP_TESTS" == false ]]; then
    echo "▸ Running tests..."
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -quiet \
        2>&1
    echo "✓ All tests passed."
    echo ""
fi

# ── Step 2: Build Release archive ──
echo "▸ Building Release archive..."
ARCHIVE_PATH="$ROOT_DIR/build/${APP_NAME}.xcarchive"
rm -rf "$ARCHIVE_PATH"

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -archivePath "$ARCHIVE_PATH" \
    ONLY_ACTIVE_ARCH=NO \
    -quiet \
    2>&1

echo "✓ Archive built: $ARCHIVE_PATH"
echo ""

# ── Step 3: Export app bundle ──
echo "▸ Exporting app bundle..."
mkdir -p "$ARCHIVE_DIR"

# The .app lives inside the xcarchive
ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app"

if [[ ! -d "$ARCHIVED_APP" ]]; then
    echo "ERROR: Archived app not found at $ARCHIVED_APP"
    exit 1
fi

# Copy to Releases/
DEST_APP="$ARCHIVE_DIR/${APP_NAME}.app"
rm -rf "$DEST_APP"
cp -R "$ARCHIVED_APP" "$DEST_APP"

echo "✓ App exported: $DEST_APP"
echo ""

# ── Step 4: Verify binary architectures ──
BINARY="$DEST_APP/Contents/MacOS/${APP_NAME}"
echo "▸ Verifying binary architectures..."
ARCHS="$(lipo -archs "$BINARY" 2>&1 || true)"
echo "  Architectures: $ARCHS"

if [[ "$ARCHS" == *"arm64"* ]] && [[ "$ARCHS" == *"x86_64"* ]]; then
    echo "✓ Universal binary (arm64 + x86_64)"
elif [[ "$ARCHS" == *"arm64"* ]]; then
    echo "✓ Apple Silicon binary (arm64)"
else
    echo "⚠ Unexpected architectures: $ARCHS"
fi
echo ""

# ── Cleanup ──
rm -rf "$ROOT_DIR/build"

echo "========================================"
echo " Build pipeline complete!"
echo " Output: $DEST_APP"
echo ""
echo " Next step: ./scripts/sign-and-notarize-releases.sh"
echo "========================================"
