# Agent Bell

macOS Notification Center hooks for `codex` and `claude`.

## What It Does

- Uses one shared notifier for both CLIs.
- Shows notifications as `title + body` only.
- Sends the full message body to macOS after whitespace cleanup.
- Plays a sound for completion notifications.
- Deduplicates identical notifications for 20 seconds.

## Files

- `scripts/notify-agent.sh`: Common macOS notifier.
- `hooks/codex-notify.sh`: Codex `notify` adapter.
- `hooks/claude-hook.sh`: Claude Code hook adapter.

## Requirements

- macOS
- `/usr/bin/osascript`
- `/usr/bin/jq`

## Notification Format

- Title examples: `🔔 Codex 완료`, `🔔 Claude 완료`, `❓ Codex 확인 필요`
- Body: raw source message with newlines, tabs, and repeated spaces collapsed to single spaces
- No subtitle
- No `Title:` prefix text
- No Markdown styling

If the source message is empty, the notifier falls back to:

- `작업이 끝났어요` for completion
- `사용자 답변이나 승인이 필요합니다` for question events

## Manual Test

Run the shared notifier directly:

```bash
/Users/kjsdev/developer-workspace/agent-bell/scripts/notify-agent.sh \
  --source codex \
  --event completed \
  --title "Codex 완료" \
  --message "이 메시지는 요약하지 않고 가능한 한 그대로 전달합니다." \
  --sound true
```

Test the Claude adapter with a fixture payload:

```bash
printf '%s' '{"hook_event_name":"Stop","last_assistant_message":"Claude가 보낸 마지막 응답 전체를 body에 전달합니다."}' \
  | /Users/kjsdev/developer-workspace/agent-bell/hooks/claude-hook.sh
```

Test the Codex adapter with a JSON argument:

```bash
/Users/kjsdev/developer-workspace/agent-bell/hooks/codex-notify.sh \
  '{"type":"agent-turn-complete","last-assistant-message":"Codex의 마지막 응답 전체를 body에 전달합니다."}'
```

## Config Targets

Codex config:

- `~/.codex/config.toml`
- `notify = ["/Users/kjsdev/developer-workspace/agent-bell/hooks/codex-notify.sh"]`

Claude config:

- `~/.claude/settings.json`
- `hooks.Stop[0].hooks[0].command = "/Users/kjsdev/developer-workspace/agent-bell/hooks/claude-hook.sh"`

## Notes

- Codex `question/approval` notifications are not enabled in v1.
- Claude is wired for `Stop` first, with room to add `Notification` later.
- Logs are written to `/tmp/agent-bell.log`.
