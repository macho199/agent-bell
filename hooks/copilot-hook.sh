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

reason="$(printf '%s' "$raw_payload" | jq -r '.reason // ""')"

case "$reason" in
  complete)
    "$NOTIFIER" \
      --source copilot \
      --event completed \
      --title "Copilot Complete" \
      --message "" \
      --sound true
    ;;
  error)
    "$NOTIFIER" \
      --source copilot \
      --event completed \
      --title "⚠️ Copilot Error" \
      --message "An error occurred during the session" \
      --sound true
    ;;
  *)
    ;;
esac

exit 0
