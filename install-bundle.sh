#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/scripts/environment.sh"
pycab_require_deck
for tool in flatpak python3 sha256sum install pgrep; do
  command -v "$tool" >/dev/null || { echo "ERROR: Missing $tool" >&2; exit 1; }
done
[[ -f "$ROOT/PyCab.flatpak" && -f "$ROOT/PyCab.flatpak.sha256" ]] || {
  echo "ERROR: Bundle and checksum must be beside install-bundle.sh" >&2; exit 1;
}
(cd "$ROOT" && sha256sum -c PyCab.flatpak.sha256)
echo "Installing bundled PyCab Flatpak..."
flatpak install --user --reinstall -y "$ROOT/PyCab.flatpak"
flatpak info --user io.github.cdswindell.PyCab
install -Dm755 "$ROOT/pycab-steam" "$HOME/.local/bin/pycab-steam"
if pgrep -x steam >/dev/null 2>&1; then
  echo "Steam is running. Exit Steam completely in Desktop Mode, then run:"
  echo "  python3 $ROOT/scripts/install-steam-shortcut.py"
else
  python3 "$ROOT/scripts/install-steam-shortcut.py"
fi
echo "PyCab bundle installed. Restart Steam and launch PyCab from Library > Non-Steam."
