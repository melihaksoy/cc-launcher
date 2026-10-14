#!/bin/bash
# Uninstall cc-launcher: stop it, then remove the LaunchAgent, scripts, launcher folder and config.
#
#   ./uninstall.sh [--purge]
#
# --purge also deletes the one-time code secret from the Keychain and the code state.

set -uo pipefail

CONFIG="$HOME/.config/cc-launcher/config"

config_get() {
  local key="$1" default="$2" line="" value=""
  if [ -f "$CONFIG" ]; then
    line="$(grep -E "^${key}=" "$CONFIG" | tail -1 || true)"
    value="${line#*=}"
  fi
  value="${value/#\~/$HOME}"
  printf '%s' "${value:-$default}"
}

BIN_DIR="$(config_get BIN_DIR "$HOME/.claude/bin")"
LAUNCHER_DIR="$(config_get LAUNCHER_DIR "$HOME/.claude/launcher")"
STATE_DIR="$(config_get STATE_DIR "$HOME/.local/state/cc-launcher")"
LABEL="$(config_get LAUNCH_AGENT_LABEL "local.cc-launcher")"
SERVICE="$(config_get KEYCHAIN_SERVICE "cc-launcher-totp")"

if [ -x "$BIN_DIR/cc-launcher" ]; then
  "$BIN_DIR/cc-launcher" stop || echo "warning: stop failed; check 'claude agents' for a session named Launcher." >&2
fi

rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -f "$BIN_DIR/cc-tab" "$BIN_DIR/cc-totp" "$BIN_DIR/cc-launcher"
rm -rf "$LAUNCHER_DIR"
rm -f "$CONFIG"
rmdir "$(dirname "$CONFIG")" 2>/dev/null

if [ "${1:-}" = "--purge" ]; then
  security delete-generic-password -a "$USER" -s "$SERVICE" >/dev/null 2>&1 && echo "Deleted the Keychain secret."
  rm -rf "$STATE_DIR"
fi

echo "cc-launcher removed. Remove the authenticator entry yourself if you used --purge."
