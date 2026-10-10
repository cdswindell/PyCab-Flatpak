#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/scripts/environment.sh"
pycab_require_mac
cd "$ROOT"
for tool in git gh curl python3; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
gh auth status >/dev/null
[[ "$(git branch --show-current)" == "master" ]] || { echo "ERROR: Switch to master before publishing." >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "ERROR: Working tree is not clean." >&2; exit 1; }
git fetch origin master --tags
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/master)" ]] || { echo "ERROR: master is not synchronized with origin/master." >&2; exit 1; }

echo "Finding latest stable PyLegacy release tag..."
VERSION="$(gh api 'repos/cdswindell/PyLegacy/git/matching-refs/tags/v' --paginate --jq '.[].ref' |
  sed -nE 's@^refs/tags/v([0-9]+\.[0-9]+\.[0-9]+)$@\1@p' |
  sort -V | tail -n 1)"
[[ -n "$VERSION" ]] || { echo "ERROR: No stable PyLegacy vX.Y.Z tag found." >&2; exit 1; }
TAG="v$VERSION"
echo "Selected PyTrain $TAG"
for package in pytrain-ogr-deck pytrain-ogr; do
  echo "Verifying $package==$VERSION on PyPI..."
  python3 - "$package" "$VERSION" <<'PY'
import json, sys, urllib.request
package, version = sys.argv[1:]
try:
    with urllib.request.urlopen(f"https://pypi.org/pypi/{package}/{version}/json", timeout=20) as response:
        metadata = json.load(response)
    files = metadata.get("urls", [])
    assert files and any(not f.get("yanked", False) for f in files)
    assert metadata["info"]["version"] == version
except Exception as exc:
    sys.exit(f"ERROR: {package}=={version} is not available as a non-yanked PyPI release: {exc}")
PY
done

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "ERROR: PyCab tag $TAG already exists locally." >&2; exit 1
fi
if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "ERROR: PyCab tag $TAG already exists on origin." >&2; exit 1
fi

CURRENT="$(sed -n 's/^pytrain-ogr-deck==//p' requirements-lock.txt)"
if [[ "$CURRENT" == "$VERSION" ]]; then
  echo "Dependency lock already targets $VERSION; no regeneration needed."
else
  echo "Generating Linux dependency lock for $VERSION..."
  # Capture latest run ID before dispatch; never select a prior run.
  BEFORE="$(gh run list --repo cdswindell/PyCab-Flatpak --workflow update-lock.yml --limit 1 --json databaseId --jq '.[0].databaseId // 0')"
  gh workflow run update-lock.yml --repo cdswindell/PyCab-Flatpak --ref master -f version="$VERSION"
  RUN=""
  for _ in {1..30}; do
    RUN="$(gh run list --repo cdswindell/PyCab-Flatpak --workflow update-lock.yml --event workflow_dispatch --limit 10 --json databaseId --jq ".[] | select(.databaseId > $BEFORE) | .databaseId" | head -n 1)"
    [[ -n "$RUN" ]] && break
    sleep 3
  done
  [[ -n "$RUN" ]] || { echo "ERROR: Could not identify new lock workflow run." >&2; exit 1; }
  echo "Waiting for lock workflow run $RUN..."
  gh run watch "$RUN" --repo cdswindell/PyCab-Flatpak --exit-status
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  gh run download "$RUN" --repo cdswindell/PyCab-Flatpak --name requirements-lock --dir "$TMP"
  grep -Fxq "pytrain-ogr-deck==$VERSION" "$TMP/requirements-lock.txt" ||
    { echo "ERROR: Downloaded lock does not match $VERSION." >&2; exit 1; }
  cp "$TMP/requirements-lock.txt" requirements-lock.txt
fi

git diff -- requirements-lock.txt
echo
echo "Ready to publish PyCab $TAG from the published PyPI packages."
read -r -p "Type '$TAG' to commit, push, and tag the release: " CONFIRM
[[ "$CONFIRM" == "$TAG" ]] || { echo "Canceled. No release tag pushed."; exit 1; }

if ! git diff --quiet -- requirements-lock.txt; then
  git add requirements-lock.txt
  git commit -m "Lock PyCab dependencies for PyTrain $VERSION"
  git push origin master
fi
git tag "$TAG"
git push origin "$TAG"
echo "Published tag $TAG. GitHub Actions will build and attach the Flatpak."
echo "gh run list --repo cdswindell/PyCab-Flatpak --workflow release.yml --limit 5"
