#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/scripts/environment.sh"
pycab_require_deck
for tool in gh flatpak sha256sum; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading latest published PyCab release..."
gh release download --repo cdswindell/PyCab-Flatpak --pattern 'PyCab.flatpak*' --dir "$TMP"
[[ -s "$TMP/PyCab.flatpak" && -s "$TMP/PyCab.flatpak.sha256" ]] || {
  echo "ERROR: Missing bundle or checksum." >&2; exit 1;
}
(cd "$TMP" && sha256sum -c PyCab.flatpak.sha256)
flatpak install --user --reinstall -y "$TMP/PyCab.flatpak"
flatpak info --user io.github.cdswindell.PyCab
flatpak run --command=/app/bin/python3 io.github.cdswindell.PyCab -c "from importlib.metadata import version; print('PyTrain:', version('pytrain-ogr-deck'))"
echo "Installed. Launch in Steam Gaming Mode or a local Deck desktop console."
