#!/bin/sh
# Builds build/SimpleText.app for release (universal) and signs it.
#
#   Scripts/bundle.sh             build/SimpleText.app
#   INSTALL=1 Scripts/bundle.sh   also copies it to /Applications
#   SIGN_IDENTITY="Developer ID Application: …" Scripts/bundle.sh   signs with that identity ("-" for ad hoc)
#
# SimpleText is a SwiftPM executable (Sources/SimpleText), put in a bundle here with its icon and help.
set -e
cd "$(dirname "$0")/.."
# The version shown by the Finder, About and the status bar: bump it here, and only here (CHANGELOG.md says
# what changed; a release is tagged vX.Y.Z). The build number counts commits.
VERSION="0.9.0"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

if [ ! -f Resources/icon.icns ]; then
    swift Scripts/make-icon.swift
fi

swift build -c release --arch arm64 --arch x86_64 --product SimpleText
PRODUCTS=".build/apple/Products/Release"

APP="build/SimpleText.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Stamped in the bundle's copy only: Resources/Info.plist keeps the placeholders
sed -i '' -e "s/@VERSION@/$VERSION/" -e "s/@BUILD@/$BUILD/" "$APP/Contents/Info.plist"
if grep -q '@VERSION@\|@BUILD@' "$APP/Contents/Info.plist"; then
    echo "error: the version was not stamped into the app's Info.plist" >&2
    exit 1
fi
cp Resources/icon.icns "$APP/Contents/Resources/"
cp -R Resources/Help "$APP/Contents/Resources/Help"
# Empty localisations: AppKit then shows its own strings (Sans titre, Ouvrir…) in French.
cp -R Resources/fr.lproj "$APP/Contents/Resources/fr.lproj"
mkdir -p "$APP/Contents/Resources/en.lproj"
cp "$PRODUCTS/SimpleText" "$APP/Contents/MacOS/SimpleText"

# Signing. A real identity keeps the app's identity stable across rebuilds, so macOS remembers its permissions.
if [ -z "${SIGN_IDENTITY:-}" ]; then
    IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    SIGN_IDENTITY="$(echo "$IDENTITIES" | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
    [ -n "$SIGN_IDENTITY" ] || SIGN_IDENTITY="$(echo "$IDENTITIES" | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)"
    [ -n "$SIGN_IDENTITY" ] || SIGN_IDENTITY="-"
fi
mkdir -p build
if ! codesign --force --timestamp=none --sign "$SIGN_IDENTITY" "$APP" 2>build/codesign.log; then
    echo "warning: signing with '$SIGN_IDENTITY' failed ($(tail -1 build/codesign.log)); signing ad hoc instead" >&2
    SIGN_IDENTITY="-"
    codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
echo "signed: $SIGN_IDENTITY" >&2

if [ "${INSTALL:-0}" = "1" ]; then
    TARGET="/Applications/SimpleText.app"
    if pgrep -f "$TARGET/Contents/MacOS/SimpleText" >/dev/null; then
        echo "note: SimpleText is running from $TARGET; quit and reopen it to get this build" >&2
    fi
    rm -rf "$TARGET.new"
    ditto "$APP" "$TARGET.new"
    rm -rf "$TARGET"
    mv "$TARGET.new" "$TARGET"
    echo "installed: $TARGET" >&2
fi
echo "built: $APP ($(du -sh "$APP" | cut -f1))"
