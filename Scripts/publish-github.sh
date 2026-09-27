#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/Scripts/release-config.sh"

REPO_NAME="${1:-$GITHUB_REPOSITORY_NAME}"
OWNER="$GITHUB_OWNER"

if [ "$REPO_NAME" != "$GITHUB_REPOSITORY_NAME" ]; then
  echo "Repository name '$REPO_NAME' does not match the configured update target '$GITHUB_REPOSITORY_NAME'." >&2
  echo "Set GITHUB_REPOSITORY_NAME='$REPO_NAME' when running this script and all release commands." >&2
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required." >&2
  echo "Install it with: brew install gh" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Authenticate first: gh auth login" >&2
  exit 1
fi

if [ ! -d .git ]; then
  git init -b main
  git add .
  git -c user.name="$OWNER" \
      -c user.email="$OWNER@users.noreply.github.com" \
      commit -m "Initial MVP: MacTranslate Foundation Models translator"
fi

if git remote get-url origin >/dev/null 2>&1; then
  echo "origin already exists: $(git remote get-url origin)" >&2
  exit 1
fi

gh repo create "$OWNER/$REPO_NAME" \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "MacTranslate: a minimal macOS translator powered by Apple Foundation Models"

echo "Created and pushed public repository: https://github.com/$OWNER/$REPO_NAME"
