#!/usr/bin/env bash
# Shared, strict host/session checks for PyCab tools.
pycab_require_mac() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: This command must run on the development Mac (macOS)." >&2
    exit 1
  fi
}
pycab_require_deck() {
  if [[ "$(uname -s)" != "Linux" ]] || [[ ! -f /etc/os-release ]] || ! grep -qi 'steamos' /etc/os-release; then
    echo "ERROR: This command must run on the Steam Deck (SteamOS)." >&2
    exit 1
  fi
}
pycab_require_deck_console() {
  pycab_require_deck
  if [[ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]] || [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    echo "ERROR: Launch PyCab from a local Steam Deck graphical console, not SSH." >&2
    exit 1
  fi
}
