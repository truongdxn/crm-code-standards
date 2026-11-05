#!/bin/sh
# Publish the generated "All rules" page and the contribution guide to the project wiki.
# Only these two pages are managed by CI; other wiki pages (e.g. home) are left untouched.
#
# Required env:
#   WIKI_URL  git URL of the wiki repo (with credentials in CI)
# Optional env:
#   SRC       repo checkout to publish from (default: current directory)
#   PAGE      generated All rules page (default: $SRC/dist/All-rules.md)
set -eu

: "${WIKI_URL:?WIKI_URL is required}"
SRC=$(cd "${SRC:-.}" && pwd)
PAGE=${PAGE:-$SRC/dist/All-rules.md}
[ -f "$PAGE" ] || { echo "Missing $PAGE: run build/build_rules.py --out first." >&2; exit 1; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if ! git clone -q --depth 1 "$WIKI_URL" "$WORK/wiki"; then
    echo "Cannot clone the wiki. Create its first page in the GitLab UI and check WIKI_TOKEN." >&2
    exit 1
fi
cd "$WORK/wiki"

cp "$PAGE" All-rules.md
cp "$SRC/CONTRIBUTING.md" Contributing.md

git add All-rules.md Contributing.md
if git diff --cached --quiet; then
    echo "Wiki already up to date."
    exit 0
fi

git -c user.name="CI Wiki Bot" -c user.email="ci-wiki-bot@noreply" \
    commit -q -m "Sync from ${CI_PROJECT_PATH:-local}@${CI_COMMIT_SHORT_SHA:-$(git -C "$SRC" rev-parse --short HEAD)}"
git push -q origin HEAD
echo "Wiki updated:"
git show --stat --format='  %s' HEAD | tail -n +2
