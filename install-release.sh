#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/scripts/environment.sh"
pycab_require_deck
for tool in curl python3 flatpak sha256sum; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Finding latest published PyCab release..."
curl --fail --silent --show-error --location --retry 3 \
  -H 'Accept: application/vnd.github+json' \
  'https://api.github.com/repos/cdswindell/PyCab-Flatpak/releases/latest' \
  -o "$TMP/release.json"

python3 - "$TMP/release.json" "$TMP/asset-urls.txt" <<'PY'
import json
import sys
from pathlib import Path

release = json.loads(Path(sys.argv[1]).read_text())
assets = {asset["name"]: asset["browser_download_url"] for asset in release.get("assets", [])}
names = ("PyCab.flatpak", "PyCab.flatpak.sha256")
missing = [name for name in names if name not in assets]
if missing:
    sys.exit(f"ERROR: Release {release.get('tag_name', '?')} missing assets: {', '.join(missing)}")
Path(sys.argv[2]).write_text("\n".join(assets[name] for name in names) + "\n")
print(f"Downloading PyCab release {release['tag_name']}...")
PY

bundle_url="$(sed -n '1p' "$TMP/asset-urls.txt")"
checksum_url="$(sed -n '2p' "$TMP/asset-urls.txt")"
curl --fail --show-error --silent --location --retry 3 -o "$TMP/PyCab.flatpak" "$bundle_url"
curl --fail --show-error --silent --location --retry 3 -o "$TMP/PyCab.flatpak.sha256" "$checksum_url"
[[ -s "$TMP/PyCab.flatpak" && -s "$TMP/PyCab.flatpak.sha256" ]] || {
  echo "ERROR: Missing bundle or checksum." >&2; exit 1;
}
(cd "$TMP" && sha256sum -c PyCab.flatpak.sha256)
flatpak install --user --reinstall -y "$TMP/PyCab.flatpak"
flatpak info --user io.github.cdswindell.PyCab
flatpak run --command=/app/bin/python3 io.github.cdswindell.PyCab -c "from importlib.metadata import version; print('PyTrain:', version('pytrain-ogr-deck'))"
echo "Installed. Launch in Steam Gaming Mode or a local Deck desktop console."
