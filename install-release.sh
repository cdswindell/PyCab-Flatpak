#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/scripts/environment.sh"
pycab_require_deck
for tool in curl python3 flatpak sha256sum; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
VERSION=""
if (( $# )); then
  if (( $# != 2 )) || [[ "$1" != "--version" || ! "$2" =~ ^v[0-9]+[.][0-9]+[.][0-9]+(-[1-9][0-9]*)?$ ]]; then
    echo "Usage: $0 [--version vX.Y.Z[-N]]" >&2
    exit 2
  fi
  VERSION="$2"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

RELEASE_API="https://api.github.com/repos/cdswindell/PyCab-Flatpak/releases/latest"
if [[ -n "$VERSION" ]]; then
  RELEASE_API="https://api.github.com/repos/cdswindell/PyCab-Flatpak/releases/tags/$VERSION"
  echo "Finding published PyCab release $VERSION..."
else
  echo "Finding latest published PyCab release..."
fi
curl --fail --silent --show-error --location --retry 3 \
  -H 'Accept: application/vnd.github+json' \
  "$RELEASE_API" \
  -o "$TMP/release.json"

python3 - "$TMP/release.json" "$TMP/asset-urls.txt" <<'PY'
import json
import sys
from pathlib import Path

release = json.loads(Path(sys.argv[1]).read_text())
import re
tag = release.get("tag_name", "")
if not re.fullmatch(r"v[0-9]+[.][0-9]+[.][0-9]+(?:-[1-9][0-9]*)?", tag) or release.get("draft") or release.get("prerelease"):
    sys.exit("ERROR: Release is not a published stable PyCab release")
assets = {asset["name"]: asset["browser_download_url"] for asset in release.get("assets", [])}
if not all(url.startswith(f"https://github.com/cdswindell/PyCab-Flatpak/releases/download/{tag}/") for url in assets.values()):
    sys.exit("ERROR: Unexpected release asset URL")
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
# Older release checksums contain the CI runner's absolute build path.
# Verify the downloaded bundle by basename, without trusting that path.
python3 - "$TMP/PyCab.flatpak.sha256" "$TMP/PyCab.flatpak.check" <<'PY'
import re
import sys
from pathlib import Path

line = Path(sys.argv[1]).read_text().strip()
match = re.fullmatch(r"([0-9a-fA-F]{64})\s+\*?(.+)", line)
if not match or Path(match.group(2)).name != "PyCab.flatpak":
    sys.exit("ERROR: Invalid PyCab checksum manifest.")
Path(sys.argv[2]).write_text(f"{match.group(1)}  PyCab.flatpak\n")
PY
(cd "$TMP" && sha256sum -c PyCab.flatpak.check)

# Fresh Steam Decks may not have Flathub or PyCab's required runtime installed.
echo "Configuring Flathub for the current user..."
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
echo "Ensuring PyCab's Freedesktop runtime (26.08) is installed..."
flatpak install --user -y flathub org.freedesktop.Platform//26.08

if [[ -n "$VERSION" ]]; then
  RELEASE_TAG="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["tag_name"])' "$TMP/release.json")"
  [[ "$RELEASE_TAG" == "$VERSION" ]] || { echo "ERROR: Release mismatch." >&2; exit 1; }
  echo "WARNING: Rolling back to $VERSION; persistent application data will be retained."
  read -r -p "Type '$VERSION' to confirm rollback: " CONFIRM
  [[ "$CONFIRM" == "$VERSION" ]] || { echo "Canceled."; exit 1; }
fi
flatpak install --user --reinstall -y "$TMP/PyCab.flatpak"
flatpak info --user io.github.cdswindell.PyCab
flatpak run --command=/app/bin/python3 io.github.cdswindell.PyCab -c "from importlib.metadata import version; print('PyTrain:', version('pytrain-ogr-deck'))"
# Use the host launcher packaged with the installed release.
LAUNCHER_TMP="$TMP/pycab-steam"
BUNDLED_LAUNCHER=false
if flatpak run --command=cat io.github.cdswindell.PyCab /app/share/pycab/pycab-steam > "$LAUNCHER_TMP" 2>/dev/null && [[ -s "$LAUNCHER_TMP" ]]; then
  install -Dm755 "$LAUNCHER_TMP" "$HOME/.local/bin/pycab-steam"
  BUNDLED_LAUNCHER=true
else
  echo "Historical release has no bundled host launcher; retaining current launcher."
  if [[ ! -x "$HOME/.local/bin/pycab-steam" ]]; then
    install -Dm755 "$ROOT/pycab-steam" "$HOME/.local/bin/pycab-steam"
  fi
fi
if pgrep -x steam >/dev/null 2>&1; then
  echo "Steam is running; exit Steam completely, then run:"
  echo "  python3 $ROOT/scripts/install-steam-shortcut.py"
else
  python3 "$ROOT/scripts/install-steam-shortcut.py"
fi
echo
echo "Verifying PyCab installation..."
APP_ID=io.github.cdswindell.PyCab
flatpak info --user "$APP_ID" >/dev/null
flatpak info --user org.freedesktop.Platform//26.08 >/dev/null
INSTALLED_TAG="$(flatpak run --command=cat "$APP_ID" /app/share/pycab/release-tag)"
EXPECTED_TAG="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["tag_name"])' "$TMP/release.json")"
[[ "$INSTALLED_TAG" == "$EXPECTED_TAG" ]] || {
  echo "ERROR: Installed release $INSTALLED_TAG does not match downloaded $EXPECTED_TAG" >&2; exit 1;
}
flatpak run --command=test "$APP_ID" -x /app/bin/pycab-flatpak || {
  echo "ERROR: Flatpak launcher missing." >&2; exit 1;
}
[[ -x "$HOME/.local/bin/pycab-steam" ]] || {
  echo "ERROR: Host launcher missing or not executable." >&2; exit 1;
}
if [[ "$BUNDLED_LAUNCHER" == true ]]; then
  cmp -s "$LAUNCHER_TMP" "$HOME/.local/bin/pycab-steam" || {
    echo "ERROR: Host launcher differs from installed release." >&2; exit 1;
  }
fi
echo "Verified: release $INSTALLED_TAG, runtime 26.08, Flatpak entry point and host launcher."
flatpak run --command=cat "$APP_ID" /app/share/pycab/build-info 2>/dev/null || echo "Build metadata unavailable in this historical release."
if ! pgrep -x steam >/dev/null 2>&1; then
  python3 "$ROOT/scripts/install-steam-shortcut.py" --dry-run
else
  echo "Steam shortcut verification deferred until Steam exits."
fi
echo "Installed. Launch in Steam Gaming Mode or a local Deck desktop console."
