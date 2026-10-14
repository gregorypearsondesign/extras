#!/usr/bin/env bash
# Publish one Extras experiment page.
# Usage: scripts/publish.sh <source-html> <slug> "<Readable name>" [--no-push]
#   Copies <source-html> to <slug>-figma-motion/index.html, runs the scrub
#   check, commits "Add <Readable name> experiment", pushes main, waits for the
#   Vercel deploy to serve the new file, and prints the live URL.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
# shellcheck source=site.env
[[ -f scripts/site.env ]] || { echo "publish: scripts/site.env missing (needs SITE_URL)" >&2; exit 2; }
source scripts/site.env   # provides SITE_URL

PUSH=1
args=()
for a in "$@"; do
  case "$a" in
    --no-push) PUSH=0 ;;
    *) args+=("$a") ;;
  esac
done
if [[ ${#args[@]} -ne 3 ]]; then
  echo "usage: scripts/publish.sh <source-html> <slug> \"<Readable name>\" [--no-push]" >&2
  exit 2
fi
SRC="${args[0]}"; SLUG="${args[1]}"; NAME="${args[2]}"

# Only a single finished .html page may be published. Never notes, playbooks, build files or READMEs.
[[ -f "$SRC" ]] || { echo "publish: source not found: $SRC" >&2; exit 2; }
base="$(basename "$SRC")"
case "$SRC" in
  *.html) ;;
  *) echo "publish: source must be an .html file" >&2; exit 2 ;;
esac
if [[ "$SRC" == */_build/* || "$base" == README* || "$base" == playbook* ]]; then
  echo "publish: refusing to publish $SRC" >&2; exit 2
fi
[[ "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "publish: slug must be lowercase-kebab-case" >&2; exit 2; }

if [[ -n "$(git diff --cached --name-only)" ]]; then
  echo "publish: there are already staged changes; commit or unstage them first" >&2; exit 2
fi

DEST="$SLUG-figma-motion/index.html"
VERB="Add"; [[ -f "$DEST" ]] && VERB="Update"
mkdir -p "$(dirname "$DEST")"
cp "$SRC" "$DEST"

if ! scripts/scrub.sh "$DEST"; then
  echo "publish: scrub failed; $DEST left uncommitted for you to fix" >&2
  exit 1
fi

git add "$DEST"
if git diff --cached --quiet -- "$DEST"; then
  echo "publish: $DEST is unchanged, nothing to commit"
else
  git commit -q -m "$VERB $NAME experiment" -- "$DEST"
  git log --oneline -1
fi

URL="$SITE_URL/$SLUG-figma-motion"
if [[ $PUSH -eq 0 ]]; then
  echo "Committed locally (--no-push). Will be live at: $URL"
  exit 0
fi

git push -q origin main

# Wait until the live page serves exactly the committed file.
want="$(shasum -a 256 < "$DEST" | cut -d' ' -f1)"
echo "Waiting for Vercel deploy..."
for _ in $(seq 1 60); do
  got="$(curl -fsSL -H 'Cache-Control: no-cache' "$URL/?v=$(date +%s)" 2>/dev/null | shasum -a 256 | cut -d' ' -f1 || true)"
  if [[ "$got" == "$want" ]]; then
    echo "Live: $URL"
    exit 0
  fi
  sleep 5
done
echo "publish: pushed, but the deploy did not show up within 5 minutes. Check: $URL" >&2
exit 1
