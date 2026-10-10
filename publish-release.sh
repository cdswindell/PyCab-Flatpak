#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/scripts/environment.sh"
pycab_require_mac
cd "$ROOT"
REBUILD=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --rebuild) [[ "$REBUILD" == false ]] || { echo "Duplicate --rebuild" >&2; exit 2; }; REBUILD=true ;;
    --dry-run) [[ "$DRY_RUN" == false ]] || { echo "Duplicate --dry-run" >&2; exit 2; }; DRY_RUN=true ;;
    *) echo "Usage: $0 [--rebuild] [--dry-run]" >&2; exit 2 ;;
  esac
done
for tool in git gh curl python3; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
gh auth status >/dev/null
if [[ "$DRY_RUN" == false ]]; then
  [[ "$(git branch --show-current)" == "master" ]] || { echo "ERROR: Switch to master before publishing." >&2; exit 1; }
  [[ -z "$(git status --porcelain)" ]] || { echo "ERROR: Working tree is not clean." >&2; exit 1; }
  git fetch origin master --tags
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/master)" ]] || { echo "ERROR: master is not synchronized with origin/master." >&2; exit 1; }
else
  echo "DRY RUN: No files, commits, tags, workflows, or remote refs will be changed."
  echo "Branch: $(git branch --show-current) (publishing requires clean, synchronized master)"
fi

if [[ "$REBUILD" == true ]]; then
  VERSION="$(sed -n 's/^pytrain-ogr-deck==//p' requirements-lock.txt)"
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: Lock must pin exactly one stable pytrain-ogr-deck version." >&2; exit 1; }
  echo "Rebuilding pinned PyTrain v$VERSION"
else
  echo "Finding latest stable PyLegacy release tag (numeric, no v prefix)..."
  VERSION="$(gh api 'repos/cdswindell/PyLegacy/git/matching-refs/tags/' --paginate --jq '.[].ref' |
    sed -nE 's@^refs/tags/([0-9]+\.[0-9]+\.[0-9]+)$@\1@p' |
    sort -V | tail -n 1)"
  [[ -n "$VERSION" ]] || { echo "ERROR: No stable PyLegacy X.Y.Z tag found." >&2; exit 1; }
  TAG="v$VERSION"
  echo "Selected PyTrain $TAG"
fi
if [[ "$REBUILD" == true ]]; then
  # Never rewrite existing release tags. Allocate the next packaging revision.
  NEXT=1
  while git rev-parse -q --verify "refs/tags/v$VERSION-$NEXT" >/dev/null || git ls-remote --exit-code --tags origin "refs/tags/v$VERSION-$NEXT" >/dev/null 2>&1; do
    NEXT=$((NEXT + 1))
  done
  TAG="v$VERSION-$NEXT"
fi
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

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null ||
   git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN: Tag $TAG already exists; an actual publication would stop."
  else
    echo "ERROR: PyCab tag $TAG already exists." >&2
    exit 1
  fi
fi

CURRENT="$(sed -n 's/^pytrain-ogr-deck==//p' requirements-lock.txt)"
if [[ "$CURRENT" == "$VERSION" ]]; then
  echo "Dependency lock already targets $VERSION; no regeneration needed."
else
  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN: Would dispatch update-lock.yml for PyTrain $VERSION on master and download the verified artifact."
  else
    echo "Generating Linux dependency lock for $VERSION..."
    # Match a unique workflow run-name, not merely a newer run ID.
    REQUEST_ID="$(python3 -c 'import uuid; print(uuid.uuid4())')"
    EXPECTED_TITLE="Lock $VERSION / $REQUEST_ID"
    gh workflow run update-lock.yml --repo cdswindell/PyCab-Flatpak --ref master -f version="$VERSION" -f request_id="$REQUEST_ID"
    RUN=""
    for _ in {1..30}; do
      RUN="$(gh run list --repo cdswindell/PyCab-Flatpak --workflow update-lock.yml --event workflow_dispatch --limit 50 --json databaseId,displayTitle --jq ".[] | select(.displayTitle == \"$EXPECTED_TITLE\") | .databaseId" | sed -n '1p')"
      [[ -n "$RUN" ]] && break
      sleep 3
    done
    [[ -n "$RUN" ]] || { echo "ERROR: Could not identify lock workflow run $REQUEST_ID." >&2; exit 1; }
  echo "Waiting for lock workflow run $RUN..."
  gh run watch "$RUN" --repo cdswindell/PyCab-Flatpak --exit-status
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  gh run download "$RUN" --repo cdswindell/PyCab-Flatpak --name requirements-lock --dir "$TMP"
  grep -Fxq "pytrain-ogr-deck==$VERSION" "$TMP/requirements-lock.txt" ||
    { echo "ERROR: Downloaded lock does not match $VERSION." >&2; exit 1; }
  cp "$TMP/requirements-lock.txt" requirements-lock.txt
  fi
fi

git diff -- requirements-lock.txt
if [[ "$DRY_RUN" == true ]]; then
  echo "DRY RUN: Would publish PyCab $TAG using PyTrain $VERSION."
  echo "DRY RUN: Would require clean, synchronized master; commit any updated lock; push the release tag."
  exit 0
fi
echo
echo "Ready to publish PyCab $TAG using PyTrain $VERSION."
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
