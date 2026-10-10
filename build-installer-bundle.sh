#!/usr/bin/env bash
# Run on macOS from the feature-branch checkout. Produces a standalone Deck ZIP.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/scripts/environment.sh"
pycab_require_mac
for tool in curl python3 zip sha256sum; do
  # macOS has shasum rather than sha256sum; verification uses Python below.
  [[ "$tool" == sha256sum ]] && continue
  command -v "$tool" >/dev/null || { echo "ERROR: Missing $tool" >&2; exit 1; }
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/PyCab-Installer/scripts" "$TMP/PyCab-Installer/artwork" "$ROOT/dist"
echo "Fetching current published Flatpak (no application rebuild required)..."
curl -fLsS --retry 3 https://api.github.com/repos/cdswindell/PyCab-Flatpak/releases/latest -o "$TMP/release.json"
python3 - "$TMP/release.json" "$TMP/urls" <<'PY'
import json, sys
from pathlib import Path
r=json.loads(Path(sys.argv[1]).read_text())
a={x["name"]:x["browser_download_url"] for x in r.get("assets", [])}
for name in ("PyCab.flatpak", "PyCab.flatpak.sha256"):
    if name not in a: sys.exit(f"Release missing {name}")
Path(sys.argv[2]).write_text("\n".join(a[n] for n in ("PyCab.flatpak", "PyCab.flatpak.sha256")))
print("Using release",r["tag_name"])
PY
curl -fLsS --retry 3 "$(sed -n '1p' "$TMP/urls")" -o "$TMP/PyCab-Installer/PyCab.flatpak"
curl -fLsS --retry 3 "$(sed -n '2p' "$TMP/urls")" -o "$TMP/original.sha256"
python3 - "$TMP/original.sha256" "$TMP/PyCab-Installer/PyCab.flatpak" "$TMP/PyCab-Installer/PyCab.flatpak.sha256" <<'PY'
import hashlib, re, sys
from pathlib import Path
original=Path(sys.argv[1]).read_text().strip()
m=re.fullmatch(r"([0-9a-fA-F]{64})\s+\*?(.+)",original)
if not m or Path(m.group(2)).name!="PyCab.flatpak": sys.exit("Invalid release checksum")
bundle=Path(sys.argv[2])
actual=hashlib.file_digest(bundle.open("rb"),"sha256").hexdigest()
if actual.lower()!=m.group(1).lower(): sys.exit("ERROR: Flatpak checksum mismatch")
Path(sys.argv[3]).write_text(f"{actual}  PyCab.flatpak\n")
print("Flatpak SHA-256 verified.")
PY
cp "$ROOT/install-bundle.sh" "$ROOT/pycab-steam" "$TMP/PyCab-Installer/"
cp "$ROOT/scripts/environment.sh" "$ROOT/scripts/install-steam-shortcut.py" "$TMP/PyCab-Installer/scripts/"
for asset in landscape.png portrait.png hero.png square.png sidebar.png; do
  [[ -s "$ROOT/artwork/$asset" ]] || { echo "Missing artwork/$asset" >&2; exit 1; }
  cp "$ROOT/artwork/$asset" "$TMP/PyCab-Installer/artwork/"
done
chmod +x "$TMP/PyCab-Installer/install-bundle.sh" "$TMP/PyCab-Installer/pycab-steam"
OUT="$ROOT/dist/PyCab-Installer.zip"
rm -f "$OUT"
(cd "$TMP" && zip -q -r "$OUT" PyCab-Installer)
echo "Ready: $OUT"
echo "Copy this ZIP to Steam Deck, extract, exit Steam, and run ./PyCab-Installer/install-bundle.sh"
