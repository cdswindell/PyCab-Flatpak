#!/usr/bin/env bash
set -euo pipefail

APP_ID=io.github.cdswindell.PyCab
RELEASE_URL=https://github.com/cdswindell/PyCab-Flatpak/releases/latest/download/PyCab.flatpak
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP=""

cleanup() {
  [[ -n "$TMP" ]] && rm -rf "$TMP"
}
trap cleanup EXIT

install_launcher() {
  install -Dm755 "$ROOT/pycab-steam" "$HOME/.local/bin/pycab-steam"
}

if [[ "${1:-}" == "--build" ]]; then
  if ! flatpak info org.flatpak.Builder >/dev/null 2>&1; then
    echo "Missing Flatpak Builder. Install it first:"
    echo "  flatpak install --user flathub org.flatpak.Builder"
    exit 1
  fi
  echo "Building and installing $APP_ID from source..."
  flatpak run org.flatpak.Builder --user --install --force-clean "$ROOT/build-dir" "$ROOT/$APP_ID.yml"
else
  TMP="$(mktemp -d)"
  BUNDLE="$TMP/PyCab.flatpak"
  echo "Downloading the latest PyCab Flatpak release..."
  curl -fL --retry 3 -o "$BUNDLE" "$RELEASE_URL"
  echo "Installing $APP_ID..."
  flatpak install --user --noninteractive --reinstall "$BUNDLE"
fi

echo "Installing host-side Steam launcher..."
install_launcher

cat <<EOF
Installed $APP_ID.
To add it to Steam as a non-Steam game, use:
  Target:         $HOME/.local/bin/pycab-steam
  Start In:       $HOME
  Launch Options: (empty)
Set Properties > Controller > Override for PyCab to Enable Steam Input.
Test from Konsole with: flatpak run $APP_ID
EOF
