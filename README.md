# cc-launcher

Open a new Claude Code session on your Mac from the Claude phone app. The session runs in its own
iTerm2 tab, in the project you name, and you continue it from the phone through Remote Control.

```
phone: "open my app 482913"
  → Launcher (hidden Claude Code background session, Remote Control on)
  → cc-tab checks the one-time code, finds the trusted project folder
  → iTerm2 opens a tab: cd <project> && claude --remote-control <name>
  → the new session appears in the Claude app
```

> [!WARNING]
> **Disclaimer.** This is an unofficial personal tool. It is not made, reviewed or supported by
> Anthropic. It lets a phone start shell sessions on your Mac, and the sessions it opens run with
> your normal Claude Code permissions. Read [Security model](#security-model) before you install it.
> It depends on Claude Code details that are not a stable API (the `claude agents --json` output,
> the trust records in `~/.claude.json`, the Remote Control banner text), so a Claude Code update
> can break it. You use it at your own risk. The software comes with no warranty, as the
> [license](LICENSE) says.

## Requirements

- macOS with iTerm2 in `/Applications`
- Claude Code with Remote Control (a claude.ai subscription), signed in
- `jq` and `perl` (both ship with macOS)
- An authenticator app for one-time codes (any app that supports TOTP setup keys)

Tested with Claude Code 2.1.300.

## Install

```sh
git clone https://github.com/melihaksoy/cc-launcher.git
cd cc-launcher
./install.sh --projects-root /path/to/your/projects   # also: --bin-dir, --launcher-dir, --force
```

Then, in a terminal on the Mac:

1. **Trust the launcher folder once.** Run `cd ~/.claude/launcher && claude`. The trust prompt lists
   the pre-approved rules. Check that they are only the `cc-tab` and `cc-launcher` commands, accept,
   then type `/exit`.
2. **Create the one-time code secret.** Run `~/.claude/bin/cc-totp setup` and add the printed key to
   your authenticator app. Test it with `~/.claude/bin/cc-totp verify <code>`.
   Do this in a local terminal only. Never run it through Claude: the key would go into a session
   transcript.
3. **Start the launcher.** Run `~/.claude/bin/cc-launcher start`. A session named "Launcher" appears
   in the Claude app.

Recommended Claude Code settings:

- Turn on **Require trusted devices** for Remote Control (claude.ai settings, Cowork or Account page).
- Keep `"remoteControlAtStartup": false`. `cc-tab` and the launcher turn Remote Control on themselves.
- Add `ask` rules for `Edit(~/.claude/bin/**)` and `Edit(~/.claude/launcher/**)`, so a session asks
  before it edits these files.

Projects must be folders under `PROJECTS_ROOT` (the `--projects-root` folder) that Claude Code
already trusts. Open a project once on the Mac to trust it.

## Use

Send the Launcher a message with the project and a fresh code:

```
open my app 482913
open website as "Login bug" 771205
list projects 120934
```

The Launcher replies with the session link. Every `cc-tab` call needs a new code.

## Stop it

| Command | Effect |
| - | - |
| `cc-launcher stop` | Turns off the 5-minute check, stops the session, kills it if it does not stop. Also works from the phone: "stop launcher". |
| `cc-launcher status` | Shows the check, the session and its Remote Control link. |
| `claude daemon stop --any` | Stops every Claude Code background session, not only the launcher. |
| `"disableRemoteControl": true` in `~/.claude/settings.json` | Turns off Remote Control for every session on the Mac. |
| claude.ai → Account → Trusted devices | Remove a lost phone. |
| System Settings → Privacy & Security → Automation | Remove the permission to control iTerm2. Then nothing can open tabs. |

The launcher stays off after `stop` until you run `cc-launcher start`.

## How it works

- `bin/cc-launcher` starts a Claude Code background session (`claude --bg`) in the launcher folder,
  with `--remote-control`, `--setting-sources project,local`, `--strict-mcp-config` and
  `--permission-mode dontAsk`. A LaunchAgent runs `cc-launcher ensure` every 5 minutes: it starts
  the session again when the background service retired it (this happens to idle sessions under
  memory pressure), and it restarts a session older than an hour while it is idle.
- `launcher/` holds the launcher's `CLAUDE.md` and settings. The settings allow only the `cc-tab`
  and `cc-launcher status|stop|whoami` commands and deny web tools, the Keychain tool and reads of
  the scripts, the config and the code state.
- `bin/cc-tab` checks the one-time code, matches the request to a trusted folder, opens an iTerm2
  tab with AppleScript and waits for the session link.
- `bin/cc-totp` implements TOTP (RFC 6238, SHA-1, 6 digits, 30 s). The secret stays in the login
  Keychain.
- `~/.config/cc-launcher/config` holds the paths and names. The scripts read only this file, never
  environment variables, because the launcher could put variables in front of an allowed command.

## Security model

**What the launcher can do without a valid code:** reply in chat, read its own folder
(`CLAUDE.md`, settings, `launcher.log`), and run `cc-launcher status`, `stop` and `whoami`.
Someone who reaches it can stop it, or lock the code check with 15 wrong codes. They cannot open a
tab, run other commands, read other files or reach the network.

**One-time codes:** a code works once. The script also accepts the previous and next 30-second steps
for clock drift. 5 wrong codes in 15 minutes block codes for 15 minutes. 15 wrong codes in 24 hours
block them until you run `cc-totp unlock` on the Mac. A lock stops two calls from using the same
code.

**Input handling:** the project name is only compared with folder names; it never reaches a shell.
The session name keeps only `A-Z a-z 0-9 space . _ -`. The tab command uses `printf %q`, and
AppleScript gets it as an argument, not as script text.

**Tests:** `tests/totp-vectors.sh` checks the code math against the RFC 6238 test values.
`tests/permissions.sh` runs the launcher's settings with its `CLAUDE.md` excluded, asks the model to
run commands that must fail (a plain command, one chained after `cc-tab`, one inside `$(...)`), and
fails if any of them left a file on disk.

**What it does not protect:**

1. **Sessions it opens have your full Claude Code permissions.** The code protects only the start
   of a session. A running Remote Control session can be steered by any of your trusted devices,
   with no code.
2. **A normal Claude Code session can edit these scripts.** If your settings allow `Bash(*)` or
   `Edit(*)`, a session can remove the code check. The `ask` rules above make Claude ask first for
   edits, but not for every shell command.
3. **Your claude.ai sign-in is the root.** Whoever can fully sign in to your account can enroll a
   device. Protect that account (and the email or Google account behind it) with 2FA or a passkey.
4. **The launcher's instructions are soft.** A model can be talked around its `CLAUDE.md`. The
   permission rules, not the instructions, are the boundary; the permission test checks them.

## Known limits

- It needs macOS and iTerm2.
- The trust check reads the internal `projects` records in `~/.claude.json`.
- The launcher gets a new Remote Control link after every restart. Its name stays "Launcher".
- A folder that Claude Code does not trust yet stops at the trust prompt on the Mac. `cc-tab`
  refuses untrusted folders for this reason.

## Uninstall

```sh
./uninstall.sh            # --purge also deletes the Keychain secret and the code state
```

Remove the authenticator entry and any `ask` rules yourself.

## License

[MIT](LICENSE)
