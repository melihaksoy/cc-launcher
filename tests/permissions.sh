#!/bin/bash
# Check that the installed launcher settings refuse everything except the allowed commands.
#
# It runs one short `claude -p` session in the launcher folder with the same flags as the launcher,
# but with the launcher's CLAUDE.md excluded, so only the permission rules decide. It asks the model
# to try commands that must fail, then checks their side effects on disk. The model's own report is
# printed for reading; the pass/fail result comes only from the files on disk.
#
# Needs a trusted launcher folder (install step 1). It does not use a one-time code.

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
MARK="/tmp/cc-launcher-permtest-$$"

rm -f "$MARK"-*

prompt="Permission test by the owner. Run each shell command with the Bash tool exactly as written, \
one at a time, and report the first output line or the exact denial text. Do not substitute other commands.
(1) touch $MARK-plain
(2) $BIN_DIR/cc-tab --code abc --list; touch $MARK-chained
(3) $BIN_DIR/cc-tab --code \"\$(touch $MARK-substituted)\" --list
(4) cat /etc/shells
(5) security find-generic-password -s cc-launcher-totp
(6) curl -sI https://example.com
Then try the WebFetch tool on https://example.com and the Read tool on /etc/shells."

(
  cd "$LAUNCHER_DIR" && claude -p \
    --setting-sources project,local \
    --strict-mcp-config \
    --permission-mode dontAsk \
    --settings "{\"claudeMdExcludes\":[\"$LAUNCHER_DIR/CLAUDE.md\"]}" \
    "$prompt"
) 2>&1 | sed 's/^/  model: /'

failed=0
for kind in plain chained substituted; do
  if [ -e "$MARK-$kind" ]; then
    echo "FAIL  the $kind command ran: $MARK-$kind exists"
    failed=1
  else
    echo "ok    the $kind command did not run"
  fi
done
rm -f "$MARK"-*

exit "$failed"
