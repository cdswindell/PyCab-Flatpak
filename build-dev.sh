#!/usr/bin/env bash
# Trigger a development Flatpak build on GitHub and download its bundle on this Mac.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
command -v gh >/dev/null 2>&1 || { echo "ERROR: GitHub CLI (gh) is required." >&2; exit 1; }
gh auth status >/dev/null || { echo "ERROR: Run gh auth login first." >&2; exit 1; }

PYCAB_REF="${PYCAB_REF:-master}"
PYLEGACY_REF="${PYLEGACY_REF:-master}"
REPO="cdswindell/PyCab-Flatpak"
WORKFLOW="build-development.yml"

echo "Starting development build (PyCab: $PYCAB_REF; PyLegacy: $PYLEGACY_REF)..."
# Capture the run ID from the API instead of guessing which concurrent run is ours.
# gh workflow run does not return an ID, so use a unique dispatch input? The workflow
# exposes only refs; identify our run by creation time and branch after dispatch.
STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
gh workflow run "$WORKFLOW" --repo "$REPO" --ref master \
  -f "pycab_ref=$PYCAB_REF" -f "pylegacy_ref=$PYLEGACY_REF"

echo "Waiting for the dispatched workflow to appear..."
RUN_ID=""
for attempt in {1..30}; do
  RUN_ID="$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --event workflow_dispatch \
    --limit 20 --json databaseId,createdAt \
    --jq "[.[] | select(.createdAt >= \"$STARTED\")] | sort_by(.createdAt) | last | .databaseId // empty")"
  [[ -n "$RUN_ID" ]] && break
  sleep 2
done
[[ -n "$RUN_ID" ]] || { echo "ERROR: Could not locate the dispatched workflow run." >&2; exit 1; }

echo "Watching GitHub Actions run $RUN_ID..."
gh run watch "$RUN_ID" --repo "$REPO" --exit-status

mkdir -p "$ROOT/dist"
rm -f "$ROOT/dist/PyCab.flatpak" "$ROOT/dist/PyCab.flatpak.sha256"
ARTIFACT="$(gh api "repos/$REPO/actions/runs/$RUN_ID/artifacts" --jq '.artifacts[].name | select(startswith("PyCab-development-v"))' | head -n 1)"
[[ -n "$ARTIFACT" ]] || { echo "ERROR: Development bundle artifact not found." >&2; exit 1; }
echo "Downloading $ARTIFACT..."
gh run download "$RUN_ID" --repo "$REPO" \
  --name "$ARTIFACT" --dir "$ROOT/dist"

echo "Development Flatpak downloaded:"
ls -lh "$ROOT/dist/PyCab.flatpak" "$ROOT/dist/PyCab.flatpak.sha256"
echo "Copy to Deck: scp dist/PyCab.flatpak deck@steamdeck:~/"
