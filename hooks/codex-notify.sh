#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTIFIER="$ROOT_DIR/scripts/notify-agent.sh"

raw_payload=""

if [[ $# -gt 0 ]]; then
  raw_payload="$1"
fi

if [[ -z "$raw_payload" && ! -t 0 ]]; then
  raw_payload="$(cat)"
fi

if [[ -z "$raw_payload" && $# -gt 1 ]]; then
  raw_payload="$*"
fi

extract_message_from_json() {
  jq -r '
    def first_non_empty(values):
      reduce values[] as $item (null;
        if . != null and . != "" then .
        elif $item != null and $item != "" then $item
        else .
        end
      );

    first_non_empty([
      .["last-assistant-message"],
      .last_assistant_message,
      .message,
      .body,
      .content,
      (.["input-messages"] // .input_messages // [] | last?),
      .type
    ]) // ""
  ' 2>/dev/null
}

message=""

if [[ -n "$raw_payload" ]] && printf '%s' "$raw_payload" | jq -e . >/dev/null 2>&1; then
  message="$(printf '%s' "$raw_payload" | extract_message_from_json)"
else
  message="$raw_payload"
fi

"$NOTIFIER" \
  --source codex \
  --event completed \
  --title "Codex Complete" \
  --message "$message" \
  --sound true

exit 0
