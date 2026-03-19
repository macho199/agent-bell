# Agent Bell

Notification hooks for Codex CLI and Claude Code on macOS and native Windows.

Agent Bell gives both CLIs the same lightweight notification behavior:

- emoji-prefixed titles
- title + body only
- raw body text with whitespace cleanup
- best-effort sound on completion
- 20-second dedupe for identical notifications

## Supported Platforms

- macOS via shell scripts and `osascript`
- Native Windows via PowerShell scripts
- WSL is not a v1 target

## Current Scope

- Codex completion notifications
- Claude `Stop` notifications
- Shared notification style across both CLIs

Not included yet:

- Codex question or approval notifications
- Claude `Notification` event routing
- WSL-specific bridging

## Project Structure

- `scripts/notify-agent.sh`: shared macOS notifier
- `scripts/notify-agent.ps1`: shared Windows notifier
- `hooks/codex-notify.sh`: Codex hook for macOS / Unix-like shells
- `hooks/codex-notify.ps1`: Codex hook for native Windows PowerShell
- `hooks/claude-hook.sh`: Claude hook for macOS / Unix-like shells
- `hooks/claude-hook.ps1`: Claude hook for native Windows PowerShell

## Notification Format

- Title examples: `🔔 Codex Complete`, `🔔 Claude Complete`, `❓ Codex Needs Attention`
- Body: raw source message with newlines, tabs, and repeated spaces collapsed into single spaces
- No subtitle
- No Markdown formatting

Fallback body text:

- Completion: `Task complete`
- Question: `User input or approval is required`

## Quick Start

1. Clone the repository and move into it.

```bash
git clone <YOUR_REPO_URL> agent-bell
cd agent-bell
```

2. Pick a stable path for the repo and keep it there.

macOS / Unix examples below use:

```text
<REPO_PATH>/agent-bell
```

Windows examples below use:

```text
C:\path\to\agent-bell
```

## macOS / Unix Shell Setup

### Requirements

- `jq`
- `/usr/bin/osascript`

### Make The Scripts Executable

```bash
chmod +x scripts/notify-agent.sh hooks/codex-notify.sh hooks/claude-hook.sh
```

### Codex Setup

Add this to `~/.codex/config.toml`:

```toml
notify = ["<REPO_PATH>/hooks/codex-notify.sh"]
```

### Claude Setup

Add or update this in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "<REPO_PATH>/hooks/claude-hook.sh"
          }
        ]
      }
    ]
  }
}
```

## Native Windows Setup

### Requirements

- built-in `powershell.exe` or `pwsh`
- built-in .NET assemblies `System.Windows.Forms` and `System.Drawing`
- no extra PowerShell modules

### Codex Setup

Add this to `%USERPROFILE%\.codex\config.toml`:

```toml
notify = ["powershell", "-NoProfile", "-File", "C:\\path\\to\\agent-bell\\hooks\\codex-notify.ps1"]
```

### Claude Setup

Add or update this in `%USERPROFILE%\.claude\settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -File C:\\path\\to\\agent-bell\\hooks\\claude-hook.ps1"
          }
        ]
      }
    ]
  }
}
```

## Manual Test

### macOS

Shared notifier:

```bash
<REPO_PATH>/scripts/notify-agent.sh \
  --source codex \
  --event completed \
  --title "Codex Complete" \
  --message "This body is sent without summarizing it." \
  --sound true
```

Claude hook:

```bash
printf '%s' '{"hook_event_name":"Stop","last_assistant_message":"Claude sends this full response body."}' \
  | <REPO_PATH>/hooks/claude-hook.sh
```

Codex hook:

```bash
<REPO_PATH>/hooks/codex-notify.sh \
  '{"type":"agent-turn-complete","last-assistant-message":"Codex sends this full response body."}'
```

### Windows

Shared notifier:

```powershell
powershell -NoProfile -File C:\path\to\agent-bell\scripts\notify-agent.ps1 `
  -Source codex `
  -Event completed `
  -Title "Codex Complete" `
  -Message "This body is sent without summarizing it." `
  -Sound $true
```

Claude hook:

```powershell
'{"hook_event_name":"Stop","last_assistant_message":"Claude sends this full response body."}' |
  powershell -NoProfile -File C:\path\to\agent-bell\hooks\claude-hook.ps1
```

Codex hook:

```powershell
powershell -NoProfile -File C:\path\to\agent-bell\hooks\codex-notify.ps1 `
  '{"type":"agent-turn-complete","last-assistant-message":"Codex sends this full response body."}'
```

## Notes

- macOS logs default to `/tmp/agent-bell.log`
- Windows logs default to `%TEMP%\agent-bell.log`
- completion sound is best-effort on both platforms
- identical notifications are deduped for 20 seconds
