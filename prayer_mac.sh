#!/bin/bash

VOICE="Fred"   # Deep male, robotic-like voice. Try "Bruce" or "Alex" for alternatives.
PITCH=""
SPEED=""
RATE="-r 130"  # Slower, more robotic

# === Constants ===
SECONDS_ANNOUNCE=60         # Announce every second if less than this many seconds remain
MINUTES_ANNOUNCE=20         # Announce every minute if less than this many minutes remain
MINUTES_INTERVAL=10         # Announce every N minutes otherwise

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOORBELL_SOUND="$SCRIPT_DIR/bell.wav"
LOG_FILE="$SCRIPT_DIR/prayer.log"

log() {
  local msg="$1"
  local ts
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$ts] $msg" | tee -a "$LOG_FILE"
}

echo "Detecting your location..."
location=$(curl -s ipinfo.io | jq -r '.city + "," + .country')
log "Location: $location"

echo "Fetching prayer times..."
API_URL="https://muslimsalat.com/${location// /}/daily.json"

speak_remaining() {
  remaining_sec=$1
  h=$(( remaining_sec / 3600 ))
  m=$(( (remaining_sec % 3600) / 60 ))

  if [ "$h" -gt 0 ]; then
    if [ "$m" -gt 0 ]; then
      message="$h hours and $m minutes remaining until $next_prayer prayer."
    else
      message="$h hours remaining until $next_prayer prayer."
    fi
  else
    message="$m minutes remaining until $next_prayer prayer."
  fi

  if [ -f "$DOORBELL_SOUND" ]; then
    afplay "$DOORBELL_SOUND" &>/dev/null
  fi

  log "$message"
  osascript -e "display notification \"$message\" with title \"Prayer Reminder\""
  say -v "$VOICE" $RATE "$message"
}

get_next_prayer() {
  local date_arg="$1"
  local now_ts=$(date +%s)
  local is_dst=$(date +%Z | grep -qE 'EDT|CEST|DST' && echo 1 || echo 0)
  local api_url="$API_URL"
  if [ -n "$date_arg" ]; then
    api_url="https://muslimsalat.com/${location// /}/$date_arg.json"
  fi
  local response=$(curl -s "$api_url")
  if ! echo "$response" | jq . >/dev/null 2>&1; then
    log "❌ Invalid response from API"
    osascript -e "display notification \"❌ Invalid response from API\" with title \"Prayer Reminder\""
    exit 1
  fi
  local today_timings=$(echo "$response" | jq '.items[0]')
  for prayer in fajr dhuhr asr maghrib isha; do
    local raw_time=$(echo "$today_timings" | jq -r ".${prayer}")
    local adjusted_time="$raw_time"
    if [ "$is_dst" -eq 1 ]; then
      adjusted_time=$(date -j -f "%I:%M %p" "$raw_time" "+%I:%M %p" -v+1H)
    fi
    local prayer_time_24=$(date -j -f "%I:%M %p" "$adjusted_time" +"%H:%M")
    local full_time_local="$(date +%F -d "$date_arg") $prayer_time_24"
    if [ -n "$date_arg" ]; then
      full_time_local="$date_arg $prayer_time_24"
    fi
    local prayer_ts=$(date -j -f "%F %H:%M" "$full_time_local" +%s 2>/dev/null)
    if [ "$prayer_ts" -gt "$now_ts" ]; then
      echo "$prayer|$prayer_time_24|$prayer_ts|$date_arg"
      return
    fi
  done
  # If no more prayers today, return Fajr of next day
  local next_date=$(date -j -f "%Y-%m-%d" "${date_arg:-$(date +%Y-%m-%d)}" -v+1d +"%Y-%m-%d")
  local api_url_next="https://muslimsalat.com/${location// /}/$next_date.json"
  local response_next=$(curl -s "$api_url_next")
  local timings_next=$(echo "$response_next" | jq '.items[0]')
  local raw_time=$(echo "$timings_next" | jq -r ".fajr")
  local adjusted_time="$raw_time"
  if [ "$is_dst" -eq 1 ]; then
    adjusted_time=$(date -j -f "%I:%M %p" "$raw_time" "+%I:%M %p" -v+1H)
  fi
  local prayer_time_24=$(date -j -f "%I:%M %p" "$adjusted_time" +"%H:%M")
  local full_time_local="$next_date $prayer_time_24"
  local prayer_ts=$(date -j -f "%F %H:%M" "$full_time_local" +%s 2>/dev/null)
  echo "fajr|$prayer_time_24|$prayer_ts|$next_date"
}

while true; do
  # Get next prayer info: name|time|timestamp|date
  IFS="|" read next_prayer next_time target_ts next_date <<< "$(get_next_prayer "")"
  log "Next prayer: $next_prayer at $next_time"
  osascript -e "display notification \"Next prayer: $next_prayer at $next_time\" with title \"Prayer Reminder\""

  now_ts=$(date +%s)
  initial_remaining=$(( target_ts - now_ts ))
  speak_remaining "$initial_remaining"
  last_spoken_min=-1

  while true; do
    now_ts=$(date +%s)
    remaining=$(( target_ts - now_ts ))
    remaining_min=$(( remaining / 60 ))

    if [ "$remaining" -le 0 ]; then
      log "It is time for $next_prayer prayer."
      osascript -e "display notification \"It is time for $next_prayer prayer.\" with title \"Prayer Reminder\""
      say -v "$VOICE" $RATE "It is time for $next_prayer prayer."
      break

    elif [ "$remaining" -le $SECONDS_ANNOUNCE ]; then
      for ((s=remaining; s>=1; s-=2)); do
        log "$s seconds remaining..."
        osascript -e "display notification \"$s seconds remaining...\" with title \"Prayer Reminder\""
        say -v "$VOICE" $RATE "$s"
        sleep 2
      done
      log "It is time for $next_prayer prayer."
      osascript -e "display notification \"It is time for $next_prayer prayer.\" with title \"Prayer Reminder\""
      say -v "$VOICE" $RATE "It is time for $next_prayer prayer."
      break

    elif [ "$remaining_min" -le $MINUTES_ANNOUNCE ]; then
      if (( remaining_min != last_spoken_min )); then
        speak_remaining "$remaining"
        last_spoken_min=$remaining_min
      fi
      sleep 60

    elif (( remaining_min % MINUTES_INTERVAL == 0 )) && (( remaining_min != last_spoken_min )); then
      speak_remaining "$remaining"
      last_spoken_min=$remaining_min
      sleep 60

    else
      sleep 60
    fi
  done
done