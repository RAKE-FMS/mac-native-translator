#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/Scripts/release-config.sh"

usage() {
  echo "Usage: $0 <version>" >&2
  echo "Example: $0 1.0.0" >&2
}

if [ "$#" -ne 1 ] || [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  usage
  exit 2
fi
VERSION="$1"

SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
if [[ ! "$SIGNING_IDENTITY" =~ ^Apple\ Development: ]]; then
  echo "Set SIGNING_IDENTITY to an installed Apple Development signing identity." >&2
  exit 1
fi
if ! security find-identity -v -p codesigning | grep -Fq "$SIGNING_IDENTITY"; then
  echo "The signing identity is not available in the current Keychain: $SIGNING_IDENTITY" >&2
  exit 1
fi

PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$ROOT_DIR/Info.plist" 2>/dev/null || true)"
if [ -z "$PUBLIC_KEY" ]; then
  echo "SUPublicEDKey is missing. Run 'Scripts/setup-update-signing.sh' before packaging a release." >&2
  exit 1
fi

RELEASE_DIR="$ROOT_DIR/dist/releases/v$VERSION"
APP_DIR="$ROOT_DIR/dist/MacTranslate.app"
ZIP_PATH="$RELEASE_DIR/MacTranslate-$VERSION.zip"
DMG_PATH="$RELEASE_DIR/MacTranslate-$VERSION.dmg"
APPCAST_PATH="$RELEASE_DIR/appcast.xml"
NOTES_SOURCE="$ROOT_DIR/dist/release-notes-v$VERSION.md"
NOTES_PATH="$RELEASE_DIR/MacTranslate-$VERSION.md"
APPCAST_INPUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mactranslate-appcast.XXXXXX")"
trap 'rm -rf "$APPCAST_INPUT_DIR"' EXIT

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

APP_VERSION="$VERSION" \
BUILD_NUMBER="$VERSION" \
SIGNING_IDENTITY="$SIGNING_IDENTITY" \
  "$ROOT_DIR/Scripts/build-app.sh"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
hdiutil create \
  -volname MacTranslate \
  -srcfolder "$APP_DIR" \
  -format UDZO \
  "$DMG_PATH"

if [ -f "$NOTES_SOURCE" ]; then
  cp "$NOTES_SOURCE" "$NOTES_PATH"
  cp "$NOTES_PATH" "$APPCAST_INPUT_DIR/MacTranslate-$VERSION.md"
fi
cp "$ZIP_PATH" "$APPCAST_INPUT_DIR/"

(cd "$RELEASE_DIR" && shasum -a 256 "MacTranslate-$VERSION.zip" "MacTranslate-$VERSION.dmg" > SHA256SUMS)

GENERATE_APPCAST="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
if [ ! -x "$GENERATE_APPCAST" ]; then
  echo "Sparkle's generate_appcast tool was not found. Run 'swift package resolve' and try again." >&2
  exit 1
fi

"$GENERATE_APPCAST" \
  --account "$SPARKLE_KEY_ACCOUNT" \
  --download-url-prefix "${UPDATE_DOWNLOAD_URL_PREFIX}v${VERSION}/" \
  --release-notes-url-prefix "${UPDATE_DOWNLOAD_URL_PREFIX}v${VERSION}/" \
  --link "${GITHUB_REPOSITORY_URL}/releases/latest" \
  --output-path "$APPCAST_PATH" \
  "$APPCAST_INPUT_DIR"

if ! grep -Fq "<sparkle:version>$VERSION</sparkle:version>" "$APPCAST_PATH"; then
  echo "The generated appcast does not contain version $VERSION." >&2
  exit 1
fi
if ! grep -Eq 'sparkle:edSignature="[^"]+"' "$APPCAST_PATH"; then
  echo "The generated appcast is missing the EdDSA archive signature." >&2
  exit 1
fi

echo "Release artifacts created in: $RELEASE_DIR"
