#!/usr/bin/env bash
set -euo pipefail

APP_ID=io.github.cdswindell.PyCab
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$ROOT/repo"
DIST="$ROOT/dist"

cd "$ROOT"
rm -rf "$REPO" "$DIST"
mkdir -p "$DIST"

if command -v flatpak-builder >/dev/null 2>&1; then
  BUILDER=(flatpak-builder)
else
  BUILDER=(flatpak run org.flatpak.Builder)
fi

"${BUILDER[@]}" \
  --force-clean \
  --repo="$REPO" \
  build-dir \
  "$APP_ID.yml"

flatpak build-bundle "$REPO" "$DIST/PyCab.flatpak" "$APP_ID" master
(cd "$DIST" && sha256sum PyCab.flatpak > PyCab.flatpak.sha256)

echo "Created:"
ls -lh "$DIST/PyCab.flatpak" "$DIST/PyCab.flatpak.sha256"
