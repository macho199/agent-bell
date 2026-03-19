#!/usr/bin/env bash

set -u

LOG_FILE="${AGENT_BELL_LOG_FILE:-/tmp/agent-bell.log}"
DEDUPE_DIR="${AGENT_BELL_DEDUPE_DIR:-/tmp/agent-bell-dedupe}"
DEDUPE_TTL_SECONDS="${AGENT_BELL_DEDUPE_TTL_SECONDS:-20}"

SOURCE=""
EVENT=""
TITLE=""
MESSAGE=""
SOUND="false"

log() {
  local line="$1"
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$line" >> "$LOG_FILE" 2>/dev/null || true
}

normalize_text() {
  printf '%s' "$1" | tr '\r\n\t' '   ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

fallback_message_for_event() {
  case "$1" in
    question)
      printf '%s' '사용자 답변이나 승인이 필요합니다'
      ;;
    *)
      printf '%s' '작업이 끝났어요'
      ;;
  esac
}

decorate_title() {
  local event_name="$1"
  local raw_title="$2"

  case "$raw_title" in
    "🔔 "*|"❓ "*|"⚠️ "*)
      printf '%s' "$raw_title"
      return
      ;;
  esac

  case "$event_name" in
    question)
      printf '❓ %s' "$raw_title"
      ;;
    *)
      printf '🔔 %s' "$raw_title"
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE="${2:-}"
      shift 2
      ;;
    --event)
      EVENT="${2:-}"
      shift 2
      ;;
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --message)
      MESSAGE="${2:-}"
      shift 2
      ;;
    --sound)
      SOUND="${2:-false}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

SOURCE="$(normalize_text "$SOURCE")"
EVENT="$(normalize_text "$EVENT")"
TITLE="$(normalize_text "$TITLE")"
MESSAGE="$(normalize_text "$MESSAGE")"
SOUND="$(normalize_text "$SOUND")"

if [[ -z "$SOURCE" ]]; then
  SOURCE="agent"
fi

if [[ -z "$EVENT" ]]; then
  EVENT="notification"
fi

if [[ -z "$TITLE" ]]; then
  TITLE="Agent Bell 알림"
fi

if [[ -z "$MESSAGE" ]]; then
  MESSAGE="$(fallback_message_for_event "$EVENT")"
fi

TITLE="$(decorate_title "$EVENT" "$TITLE")"

mkdir -p "$DEDUPE_DIR" 2>/dev/null || true

hash_input="$(printf '%s\n%s\n%s' "$SOURCE" "$EVENT" "$MESSAGE")"
hash_key="$(printf '%s' "$hash_input" | shasum -a 256 | awk '{print $1}')"
state_file="$DEDUPE_DIR/$hash_key"
now_epoch="$(date +%s)"

if [[ -f "$state_file" ]]; then
  previous_epoch="$(tr -cd '0-9' < "$state_file" 2>/dev/null || true)"
  if [[ -n "$previous_epoch" ]]; then
    age_seconds=$((now_epoch - previous_epoch))
    if (( age_seconds >= 0 && age_seconds < DEDUPE_TTL_SECONDS )); then
      log "deduped source=$SOURCE event=$EVENT title=\"$TITLE\""
      exit 0
    fi
  fi
fi

printf '%s\n' "$now_epoch" > "$state_file" 2>/dev/null || true

log "dispatch source=$SOURCE event=$EVENT title=\"$TITLE\""

(
  /usr/bin/osascript - "$MESSAGE" "$TITLE" <<'APPLESCRIPT'
on run argv
  set notificationMessage to item 1 of argv
  set notificationTitle to item 2 of argv
  display notification notificationMessage with title notificationTitle
end run
APPLESCRIPT

  if [[ "$SOUND" == "true" ]]; then
    /usr/bin/osascript -e 'beep 1'
  fi
) >/dev/null 2>&1 &

exit 0
