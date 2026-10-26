#!/bin/sh
# Builds SimpleText.app, packages it into build/SimpleText-<version>.zip,
# computes its SHA-256 checksum, and prints the JSON manifest snippet.
#
#   ./Scripts/package-release.sh
#   REPO="cieadrienm/SimpleText" ./Scripts/package-release.sh
set -eu
cd "$(dirname "$0")/.."

if [ "${SKIP_BUILD:-0}" != "1" ]; then
    ./Scripts/bundle.sh
fi

APP="build/SimpleText.app"
PLIST="$APP/Contents/Info.plist"
if [ ! -f "$PLIST" ]; then
    echo "error: $PLIST not found" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$PLIST")"
REPO="${REPO:-cieadrienm/SimpleText}"

ZIP="build/SimpleText-${VERSION}.zip"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}/SimpleText-${VERSION}.zip"

echo ""
echo "=== Release Package Ready ==="
echo "Archive : $ZIP"
echo "Version : $VERSION (build $BUILD)"
echo "SHA-256 : $SHA256"
echo ""
echo "=== JSON Manifest Snippet ==="
cat <<EOF
{
  "$BUNDLE_ID": {
    "version": "$VERSION",
    "build": $BUILD,
    "url": "$DOWNLOAD_URL",
    "sha256": "$SHA256",
    "notes_fr": "Mise à jour de SimpleText v$VERSION.",
    "notes_en": "SimpleText v$VERSION update."
  }
}
EOF
