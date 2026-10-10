#!/usr/bin/env bash
# Package the already-built Flatpak with the Steam Deck installer and artwork.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$ROOT/dist"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
TARGET="$STAGE/PyCab-Installer"
mkdir -p "$TARGET/scripts" "$TARGET/artwork"
for file in "$DIST/PyCab.flatpak" "$DIST/PyCab.flatpak.sha256" "$ROOT/install-bundle.sh" "$ROOT/pycab-steam" "$ROOT/scripts/environment.sh" "$ROOT/scripts/install-steam-shortcut.py"; do
  [[ -s "$file" ]] || { echo "ERROR: Missing $file" >&2; exit 1; }
done
(cd "$DIST" && sha256sum -c PyCab.flatpak.sha256)
cp "$DIST/PyCab.flatpak" "$DIST/PyCab.flatpak.sha256" "$ROOT/install-bundle.sh" "$ROOT/pycab-steam" "$TARGET/"
cp "$ROOT/scripts/environment.sh" "$ROOT/scripts/install-steam-shortcut.py" "$TARGET/scripts/"
for name in landscape.png portrait.png hero.png square.png sidebar.png; do
  [[ -s "$ROOT/artwork/$name" ]] || { echo "ERROR: Missing artwork/$name" >&2; exit 1; }
  cp "$ROOT/artwork/$name" "$TARGET/artwork/"
done
chmod +x "$TARGET/install-bundle.sh" "$TARGET/pycab-steam"
rm -f "$DIST/PyCab-Installer.zip"
(cd "$STAGE" && zip -q -r "$DIST/PyCab-Installer.zip" PyCab-Installer)
echo "Created $DIST/PyCab-Installer.zip"
