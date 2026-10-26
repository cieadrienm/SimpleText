#!/bin/sh
# Builds build/SimpleText.app for release (universal) and signs it.
#
#   Scripts/bundle.sh             build/SimpleText.app
#   INSTALL=1 Scripts/bundle.sh   also copies it to /Applications
#   SIGN_IDENTITY="Developer ID Application: …" Scripts/bundle.sh   signs with that identity ("-" for ad hoc)
#   NOTARIZE=1 Scripts/bundle.sh   also has Apple notarize the app and staples the ticket (Developer ID, notarytool profile "notary")
#
# SimpleText is a SwiftPM executable (Sources/SimpleText), put in a bundle here with its icon and help.
set -e
cd "$(dirname "$0")/.."
# The version shown by the Finder, About and the status bar: bump it here, and only here (CHANGELOG.md says
# what changed; a release is tagged vX.Y.Z). The build number counts commits.
VERSION="0.11.0"
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
# Localisations: AppKit shows its own strings (Sans titre / Untitled, Ouvrir / Open…) in French or English.
cp -R Resources/fr.lproj "$APP/Contents/Resources/fr.lproj"
cp -R Resources/en.lproj "$APP/Contents/Resources/en.lproj"
cp "$PRODUCTS/SimpleText" "$APP/Contents/MacOS/SimpleText"

# Signing. A real identity keeps the app's identity stable across rebuilds, so macOS remembers its permissions.
if [ -z "${SIGN_IDENTITY:-}" ]; then
    IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    SIGN_IDENTITY="$(echo "$IDENTITIES" | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
    [ -n "$SIGN_IDENTITY" ] || SIGN_IDENTITY="$(echo "$IDENTITIES" | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)"
    [ -n "$SIGN_IDENTITY" ] || SIGN_IDENTITY="-"
fi
# Developer ID: hardened runtime and a secure timestamp, as notarization requires
case "$SIGN_IDENTITY" in
    "Developer ID Application:"*) SIGN_FLAGS="--timestamp --options runtime" ;;
    *) SIGN_FLAGS="--timestamp=none" ;;
esac
mkdir -p build
if ! codesign --force $SIGN_FLAGS --sign "$SIGN_IDENTITY" "$APP" 2>build/codesign.log; then
    echo "warning: signing with '$SIGN_IDENTITY' failed ($(tail -1 build/codesign.log)); signing ad hoc instead" >&2
    SIGN_IDENTITY="-"
    codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
echo "signed: $SIGN_IDENTITY" >&2

# NOTARIZE=1: Apple checks the app and the ticket is stapled to it, so Gatekeeper opens it without a warning
if [ "${NOTARIZE:-0}" = "1" ]; then
    case "$SIGN_IDENTITY" in
        "Developer ID Application:"*) ;;
        *) echo "error: NOTARIZE=1 needs a Developer ID Application certificate" >&2; exit 1 ;;
    esac
    ditto -c -k --keepParent "$APP" "$APP.notarize.zip"
    xcrun notarytool submit "$APP.notarize.zip" --keychain-profile "${NOTARY_PROFILE:-notary}" --wait
    rm -f "$APP.notarize.zip"
    xcrun stapler staple "$APP"
    echo "notarized and stapled" >&2
fi

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
