#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTIFIER="$ROOT_DIR/scripts/notify-agent.sh"

raw_payload=""

if [[ ! -t 0 ]]; then
  raw_payload="$(cat)"
fi

if [[ -z "$raw_payload" ]] || ! printf '%s' "$raw_payload" | jq -e . >/dev/null 2>&1; then
  exit 0
fi

hook_event_name="$(printf '%s' "$raw_payload" | jq -r '.hook_event_name // ""')"

case "$hook_event_name" in
  Stop)
    message="$(printf '%s' "$raw_payload" | jq -r '.last_assistant_message // .reason // ""')"
    "$NOTIFIER" \
      --source claude \
      --event completed \
      --title "Claude Complete" \
      --message "$message" \
      --sound true
    ;;
  Notification)
    ;;
  *)
    ;;
esac

exit 0
