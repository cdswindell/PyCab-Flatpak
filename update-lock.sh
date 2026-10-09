#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.]+)?$ ]]; then
  echo "Usage: $0 <PyTrain-version> (e.g. 2.12.1)"
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required; install it and run 'gh auth login'."
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
VERSION="$1"
REPO="cdswindell/PyCab-Flatpak"

echo "Requesting Linux/x86_64 Python 3.14.8 lock for pytrain-ogr-deck==$VERSION..."
gh workflow run update-lock.yml --repo "$REPO" --ref master -f version="$VERSION"

cat <<EOF

GitHub Actions is generating the lock (no Docker required).
View runs:
  gh run list --repo $REPO --workflow update-lock.yml --limit 5

When the run succeeds, download its artifact into this checkout:
  gh run download RUN_ID --repo $REPO --name requirements-lock --dir .

Then inspect and test:
  git diff requirements-lock.txt
  bash build-release.sh

Do not commit/tag until the new Flatpak is tested.
EOF
