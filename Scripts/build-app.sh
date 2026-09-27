#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

source "$ROOT_DIR/Scripts/release-config.sh"

APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$APP_VERSION}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

swift build -c release

APP_DIR="$ROOT_DIR/dist/MacTranslate.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
FRAMEWORKS_DIR="$APP_DIR/Contents/Frameworks"
APP_PLIST="$APP_DIR/Contents/Info.plist"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$FRAMEWORKS_DIR"

cp "$ROOT_DIR/.build/release/MacTranslate" "$MACOS_DIR/MacTranslate"
cp "$ROOT_DIR/Info.plist" "$APP_PLIST"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PLIST"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL $UPDATE_FEED_URL" "$APP_PLIST"

if ! /usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP_PLIST" >/dev/null 2>&1; then
  echo "Warning: SUPublicEDKey is not configured; in-app updates are disabled. Run Scripts/setup-update-signing.sh to enable them."
fi

SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build/artifacts/sparkle/Sparkle" -type d -name Sparkle.framework -print -quit 2>/dev/null || true)"
if [ -z "$SPARKLE_FRAMEWORK" ]; then
  echo "Sparkle.framework is missing. Run 'swift package resolve' first." >&2
  exit 1
fi

ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"

# Sign Sparkle's nested code from the inside out so each component uses the
# same identity as the app and Library Validation accepts the framework.
SPARKLE_VERSION_DIR="$FRAMEWORKS_DIR/Sparkle.framework/Versions/B"
codesign --force --sign "$SIGNING_IDENTITY" "$SPARKLE_VERSION_DIR/Updater.app"
codesign --force --sign "$SIGNING_IDENTITY" "$SPARKLE_VERSION_DIR/XPCServices/Downloader.xpc"
codesign --force --sign "$SIGNING_IDENTITY" "$SPARKLE_VERSION_DIR/XPCServices/Installer.xpc"
codesign --force --sign "$SIGNING_IDENTITY" "$SPARKLE_VERSION_DIR/Autoupdate"
codesign --force --sign "$SIGNING_IDENTITY" "$FRAMEWORKS_DIR/Sparkle.framework"
codesign --force --sign "$SIGNING_IDENTITY" "$APP_DIR"

echo "Built: $APP_DIR"
echo "Launch with: open '$APP_DIR'"
