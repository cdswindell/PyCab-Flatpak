#!/usr/bin/env bash
set -euo pipefail

APP_ID=io.github.cdswindell.PyCab
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if ! flatpak info org.flatpak.Builder >/dev/null 2>&1; then
  echo "Missing Flatpak Builder. Install it first:"
  echo "  flatpak install --user flathub org.flatpak.Builder"
  exit 1
fi

echo "Building and installing $APP_ID..."
flatpak run org.flatpak.Builder --user --install --force-clean build-dir "$APP_ID.yml"

echo "Installing host-side Steam launcher..."
install -Dm755 "$ROOT/pycab-steam" "$HOME/.local/bin/pycab-steam"

cat <<EOF
Installed $APP_ID.
To add it to Steam as a non-Steam game, use:
  Target:         $HOME/.local/bin/pycab-steam
  Start In:       $HOME
  Launch Options: (empty)
Set Properties > Controller > Override for PyCab to Enable Steam Input.
You can test from Konsole with: flatpak run $APP_ID
EOF
