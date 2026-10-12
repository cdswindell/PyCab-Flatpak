#!/usr/bin/env bash
set -euo pipefail

APP_ID=io.github.cdswindell.PyCab
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$ROOT/repo"
DIST="$ROOT/dist"
DEV_WHEELS="$ROOT/dev-wheels"

cd "$ROOT"
BUILD_STARTED=$SECONDS
phase_start() {
  PHASE_STARTED=$SECONDS
  echo "::group::PyCab phase: $1"
  echo "PHASE START: $1 ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
}
phase_end() {
  local name="$1"
  local elapsed=$((SECONDS - PHASE_STARTED))
  echo "PHASE END: $name (${elapsed}s)"
  echo "::endgroup::"
}
# Optional development override; normal release builds remain pinned to PyPI.
if [[ "${PYCAB_PREBUILT_WHEEL:-0}" != "1" ]]; then
  rm -rf "$DEV_WHEELS"
fi
if [[ -n "${PYCAB_PYLEGACY_SOURCE:-}" ]]; then
  SOURCE="$(cd "$PYCAB_PYLEGACY_SOURCE" && pwd)"
  [[ -f "$SOURCE/scripts/build_deck.py" ]] || { echo "Invalid PyLegacy checkout: $SOURCE" >&2; exit 2; }
  mkdir -p "$DEV_WHEELS"
  (cd "$SOURCE" && python3 scripts/build_deck.py --allow-local-version -o "$DEV_WHEELS")
  compgen -G "$DEV_WHEELS/*.whl" >/dev/null || { echo "No Deck wheel produced" >&2; exit 1; }
fi
if [[ "${PYCAB_PREBUILT_WHEEL:-0}" == "1" ]]; then
  compgen -G "$DEV_WHEELS/*.whl" >/dev/null || { echo "Missing prebuilt Deck wheel" >&2; exit 1; }
fi
# Embed the exact PyCab release tag (including packaging revision) in the bundle.
# Local builds may supply PYCAB_RELEASE_TAG explicitly.
RELEASE_TAG="${PYCAB_RELEASE_TAG:-${GITHUB_REF_NAME:-}}"
if [[ -z "$RELEASE_TAG" ]]; then
  # Keep the existing local build workflow working without extra arguments.
  RELEASE_TAG="v$(sed -n 's/^pytrain-ogr-deck==//p' requirements-lock.txt)"
fi
if [[ ! "$RELEASE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[1-9][0-9]*)?$ ]]; then
  echo "ERROR: Set PYCAB_RELEASE_TAG=vX.Y.Z[-N] for local builds." >&2
  exit 2
fi
printf '%s\n' "$RELEASE_TAG" > release-tag
trap 'rm -f "$ROOT/release-tag"; rm -rf "$DEV_WHEELS"' EXIT
rm -rf "$REPO" "$DIST"
mkdir -p "$DIST"

if command -v flatpak-builder >/dev/null 2>&1; then
  BUILDER=(flatpak-builder)
else
  BUILDER=(flatpak run org.flatpak.Builder)
fi

# Keep the Flatpak Builder source cache between attempts. A transient source
# download failure should not require re-downloading successful modules.
MAX_ATTEMPTS=3
phase_start "Flatpak Builder (includes module builds and Prune Cache)"
for ((attempt=1; attempt<=MAX_ATTEMPTS; attempt++)); do
  echo "Flatpak build attempt $attempt/$MAX_ATTEMPTS..."
  if "${BUILDER[@]}" \
    --force-clean \
    --repo="$REPO" \
    build-dir \
    "$APP_ID.yml"; then
    break
  fi
  if (( attempt == MAX_ATTEMPTS )); then
    echo "ERROR: Flatpak build failed after $MAX_ATTEMPTS attempts." >&2
    exit 1
  fi
  delay=$((attempt * 30))
  echo "Build failed; retrying in ${delay}s..."
  sleep "$delay"
done

phase_end "Flatpak Builder (includes module builds and Prune Cache)"
phase_start "Flatpak bundle export"
flatpak build-bundle "$REPO" "$DIST/PyCab.flatpak" "$APP_ID" master
(cd "$DIST" && sha256sum PyCab.flatpak > PyCab.flatpak.sha256)
phase_end "Flatpak bundle export"
echo "TOTAL build-release.sh elapsed: $((SECONDS - BUILD_STARTED))s"

echo "Created:"
ls -lh "$DIST/PyCab.flatpak" "$DIST/PyCab.flatpak.sha256"
