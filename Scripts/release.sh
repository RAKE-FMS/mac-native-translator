#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/Scripts/release-config.sh"

usage() {
  echo "Usage: $0 <version> [--publish] [--dry-run]" >&2
  echo "Example: $0 1.0.0 --dry-run" >&2
}

if [ "$#" -lt 1 ] || [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  usage
  exit 2
fi
VERSION="$1"
shift

PUBLISH=false
DRY_RUN=false
for option in "$@"; do
  case "$option" in
    --publish) PUBLISH=true ;;
    --dry-run) DRY_RUN=true ;;
    *) usage; exit 2 ;;
  esac
done

if $DRY_RUN && $PUBLISH; then
  echo "--dry-run cannot be combined with --publish." >&2
  exit 2
fi

NOTES_PATH="$ROOT_DIR/dist/release-notes-v$VERSION.md"
if [ ! -f "$NOTES_PATH" ]; then
  echo "Release notes are required at: $NOTES_PATH" >&2
  exit 1
fi

if ! $DRY_RUN; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI (gh) is required. Install it with: brew install gh" >&2
    exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "Authenticate first with: gh auth login" >&2
    exit 1
  fi

  REPOSITORY="$GITHUB_OWNER/$GITHUB_REPOSITORY_NAME"
  if ! VISIBILITY="$(gh repo view "$REPOSITORY" --json visibility --jq .visibility 2>/dev/null)"; then
    echo "Could not read $REPOSITORY. Create it as a public repository before creating update releases." >&2
    exit 1
  fi
  if [ "$VISIBILITY" != "PUBLIC" ]; then
    echo "The update repository $REPOSITORY is $VISIBILITY. Sparkle clients need an unauthenticated public appcast and release assets." >&2
    echo "Make this repository public or configure GITHUB_OWNER and GITHUB_REPOSITORY_NAME for a public repository." >&2
    exit 1
  fi
fi

"$ROOT_DIR/Scripts/package-release.sh" "$VERSION"

RELEASE_DIR="$ROOT_DIR/dist/releases/v$VERSION"
ZIP_PATH="$RELEASE_DIR/MacTranslate-$VERSION.zip"
DMG_PATH="$RELEASE_DIR/MacTranslate-$VERSION.dmg"
APPCAST_PATH="$RELEASE_DIR/appcast.xml"
CHECKSUMS_PATH="$RELEASE_DIR/SHA256SUMS"
ASSETS=("$ZIP_PATH" "$DMG_PATH" "$APPCAST_PATH" "$CHECKSUMS_PATH")
if [ -f "$RELEASE_DIR/MacTranslate-$VERSION.md" ]; then
  ASSETS+=("$RELEASE_DIR/MacTranslate-$VERSION.md")
fi

GH_ARGS=(-R "$GITHUB_OWNER/$GITHUB_REPOSITORY_NAME" release create "v$VERSION" "${ASSETS[@]}" --draft --title "MacTranslate $VERSION" --notes-file "$NOTES_PATH")

if $DRY_RUN; then
  printf 'gh'
  printf ' %q' "${GH_ARGS[@]}"
  printf '\n'
  printf 'Repository: %s\nArtifacts:\n' "$GITHUB_REPOSITORY_URL"
  printf '  %s\n' "${ASSETS[@]}"
  exit 0
fi

gh "${GH_ARGS[@]}"
if $PUBLISH; then
  gh -R "$GITHUB_OWNER/$GITHUB_REPOSITORY_NAME" release edit "v$VERSION" --draft=false --latest
  echo "Published v$VERSION as the latest MacTranslate release."
else
  echo "Created draft release v$VERSION. Review it on GitHub before publishing."
fi
