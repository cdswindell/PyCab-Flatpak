#!/usr/bin/env bash
set -euo pipefail

APP_ID=io.github.cdswindell.PyCab
flatpak uninstall --user --noninteractive "$APP_ID"
rm -f "$HOME/.local/bin/pycab-steam"

echo "Uninstalled $APP_ID and removed the host launcher."
echo "Remove the PyCab non-Steam shortcut manually in Steam."
echo "Application data was retained; no --delete-data option was used."
