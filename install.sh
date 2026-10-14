#!/bin/bash
# Install cc-launcher: the scripts, the launcher folder and the config file.
#
#   ./install.sh --projects-root DIR [--bin-dir DIR] [--launcher-dir DIR] [--force]
#
# --projects-root is the folder that holds your projects. It is required on the first install.
#
# It does not start anything, create the one-time code secret, or change Claude Code settings.
# An existing ~/.config/cc-launcher/config is kept: its values are the defaults for this run.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/cc-launcher"
CONFIG="$CONFIG_DIR/config"

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
PROJECTS_ROOT="$(config_get PROJECTS_ROOT "")"
STATE_DIR="$(config_get STATE_DIR "$HOME/.local/state/cc-launcher")"
SESSION_NAME="$(config_get SESSION_NAME "Launcher")"
LAUNCH_AGENT_LABEL="$(config_get LAUNCH_AGENT_LABEL "local.cc-launcher")"
KEYCHAIN_SERVICE="$(config_get KEYCHAIN_SERVICE "cc-launcher-totp")"
FORCE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bin-dir) BIN_DIR="$2"; shift 2 ;;
    --launcher-dir) LAUNCHER_DIR="$2"; shift 2 ;;
    --projects-root) PROJECTS_ROOT="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

fail() {
  echo "error: $*" >&2
  exit 1
}

check_requirements() {
  [ -n "$PROJECTS_ROOT" ] || fail "Give the folder that holds your projects: --projects-root DIR"
  [ -d "$PROJECTS_ROOT" ] || fail "--projects-root is not a folder: $PROJECTS_ROOT"
  [ "$(uname -s)" = "Darwin" ] || fail "cc-launcher needs macOS."
  [ -d "/Applications/iTerm.app" ] || fail "iTerm2 is not in /Applications."
  command -v claude >/dev/null || fail "claude is not on PATH."
  command -v jq >/dev/null || fail "jq is not on PATH."
  perl -MDigest::SHA=hmac_sha1 -MPOSIX -e 1 2>/dev/null || fail "perl with Digest::SHA and POSIX is missing."
  for dir in "$BIN_DIR" "$LAUNCHER_DIR" "$PROJECTS_ROOT" "$STATE_DIR"; do
    case "$dir" in
      /*) ;;
      *) fail "Use an absolute path: $dir" ;;
    esac
    case "$dir" in
      *[!A-Za-z0-9/._-]*) fail "Paths with spaces or special characters are not supported: $dir" ;;
    esac
  done
}

copy_file() {
  local from="$1" to="$2"
  if [ -e "$to" ] && [ "$FORCE" -ne 1 ] && ! cmp -s "$from" "$to"; then
    fail "$to exists and differs. Run again with --force to replace it."
  fi
  cp "$from" "$to"
}

render() {
  local template="$1" target="$2" tmp
  tmp="$(mktemp)"
  sed -e "s|{{BIN_DIR}}|$BIN_DIR|g" \
      -e "s|{{STATE_DIR}}|$STATE_DIR|g" \
      -e "s|{{CONFIG_DIR}}|$CONFIG_DIR|g" \
      -e "s|{{HOME}}|$HOME|g" \
      "$template" >"$tmp"
  copy_file "$tmp" "$target"
  rm -f "$tmp"
}

check_requirements

mkdir -p "$BIN_DIR" "$LAUNCHER_DIR/.claude" "$CONFIG_DIR"
for script in cc-tab cc-totp cc-launcher; do
  copy_file "$REPO/bin/$script" "$BIN_DIR/$script"
  chmod 755 "$BIN_DIR/$script"
done

render "$REPO/launcher/CLAUDE.md.template" "$LAUNCHER_DIR/CLAUDE.md"
render "$REPO/launcher/settings.json.template" "$LAUNCHER_DIR/.claude/settings.json"
render "$REPO/launcher/settings.local.json.template" "$LAUNCHER_DIR/.claude/settings.local.json"
jq . "$LAUNCHER_DIR/.claude/settings.json" >/dev/null || fail "The rendered launcher settings are not valid JSON."

# The config is rewritten from the values above, which already include the old config.
cat >"$CONFIG" <<EOF
# cc-launcher config. The scripts read only this file, never environment variables.
BIN_DIR=$BIN_DIR
PROJECTS_ROOT=$PROJECTS_ROOT
LAUNCHER_DIR=$LAUNCHER_DIR
CLAUDE_BIN_DIR=$(dirname "$(command -v claude)")
STATE_DIR=$STATE_DIR
SESSION_NAME=$SESSION_NAME
LAUNCH_AGENT_LABEL=$LAUNCH_AGENT_LABEL
KEYCHAIN_SERVICE=$KEYCHAIN_SERVICE
EOF

cat <<EOF
Installed:
  scripts   $BIN_DIR/cc-tab, cc-totp, cc-launcher
  launcher  $LAUNCHER_DIR
  config    $CONFIG

Next steps (in a terminal on the Mac):
  1. Trust the launcher folder once:  cd $LAUNCHER_DIR && claude
     Check that the prompt lists only the cc-tab and cc-launcher rules, accept it, then /exit.
  2. Create the one-time code secret:  $BIN_DIR/cc-totp setup
     Add the key to your authenticator app, then test it:  $BIN_DIR/cc-totp verify <code>
  3. Start the launcher:  $BIN_DIR/cc-launcher start
EOF
