#!/bin/sh
# Mirror the standard's Markdown files into the project wiki.
# The wiki is owned by CI: manual wiki edits are overwritten on the next run.
#
# Required env:
#   WIKI_URL  git URL of the wiki repo (with credentials in CI)
# Optional env:
#   SRC       repo checkout to publish from (default: current directory)
set -eu

: "${WIKI_URL:?WIKI_URL is required}"
SRC=$(cd "${SRC:-.}" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if ! git clone -q --depth 1 "$WIKI_URL" "$WORK/wiki"; then
    echo "Cannot clone the wiki. Create its first page in the GitLab UI and check WIKI_TOKEN." >&2
    exit 1
fi
cd "$WORK/wiki"

# Start from an empty tree so deleted rules also disappear from the wiki
git rm -rq --ignore-unmatch .

cp "$SRC/README.md" home.md              # wiki landing page
cp "$SRC/CONTRIBUTING.md" Contributing.md
cp -R "$SRC/rules" rules                 # keeps README links to rules/<SCOPE>/<ID>.md working

git add -A
if git diff --cached --quiet; then
    echo "Wiki already up to date."
    exit 0
fi

git -c user.name="CI Wiki Bot" -c user.email="ci-wiki-bot@noreply" \
    commit -q -m "Sync from ${CI_PROJECT_PATH:-local}@${CI_COMMIT_SHORT_SHA:-$(git -C "$SRC" rev-parse --short HEAD)}"
git push -q origin HEAD
echo "Wiki updated:"
git show --stat --format='  %s' HEAD | tail -n +2
