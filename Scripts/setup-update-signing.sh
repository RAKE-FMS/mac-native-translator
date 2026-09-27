#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/Scripts/release-config.sh"

swift package resolve

GENERATE_KEYS="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_keys"
if [ ! -x "$GENERATE_KEYS" ]; then
  echo "Sparkle's generate_keys tool was not found. Run 'swift package resolve' and try again." >&2
  exit 1
fi

if OUTPUT="$("$GENERATE_KEYS" --account "$SPARKLE_KEY_ACCOUNT")"; then
  :
else
  status=$?
  printf '%s\n' "$OUTPUT" >&2
  exit "$status"
fi

PUBLIC_KEY="$(printf '%s\n' "$OUTPUT" | sed -n 's/.*<string>\([A-Za-z0-9+/][A-Za-z0-9+/=]*\)<\/string>.*/\1/p' | tail -n 1)"
if [[ ! "$PUBLIC_KEY" =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
  printf '%s\n' "$OUTPUT" >&2
  echo "Could not read the EdDSA public key from generate_keys output; Info.plist was not changed." >&2
  exit 1
fi

if /usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$ROOT_DIR/Info.plist" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $PUBLIC_KEY" "$ROOT_DIR/Info.plist"
else
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $PUBLIC_KEY" "$ROOT_DIR/Info.plist"
fi

echo "Sparkle updates are configured. The public key was added to Info.plist."
echo "The private key remains in this user's login Keychain; back it up securely to sign future update archives."
