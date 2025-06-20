#!/bin/bash

LANGUAGE_MODE="en"
VOICE="Alex"
MUTE="off"
SETTINGS_FILE="$HOME/.prayer_settings_mac.conf"
ALARMS_FILE="$HOME/.prayer_alarms_mac.conf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/prayer_mac.log"
DOORBELL_SOUND="$SCRIPT_DIR/bell.wav"
ADHAN_SOUND="$SCRIPT_DIR/azan.mp3"

SECONDS_ANNOUNCE=60
MINUTES_ANNOUNCE=20
MINUTES_INTERVAL=10

load_settings() {
  [ -f "$SETTINGS_FILE" ] && source "$SETTINGS_FILE"
}

save_settings() {
  echo "LANGUAGE_MODE=\"$LANGUAGE_MODE\"" > "$SETTINGS_FILE"
  echo "VOICE=\"$VOICE\"" >> "$SETTINGS_FILE"
  echo "MUTE=\"$MUTE\"" >> "$SETTINGS_FILE"
}

set_voice() {
  if [ "$LANGUAGE_MODE" = "ar" ]; then
    VOICE="Maged"
  else
    VOICE="Alex"
  fi
  say -v "$VOICE" "Voice set to $VOICE" >/dev/null 2>&1
  log "✅ Voice set to $VOICE"
}

log() {
  local msg="$1"
  local ts
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$ts] $msg" | tee -a "$LOG_FILE"
}

announce() {
  if [ "$MUTE" = "off" ]; then
    say -v "$VOICE" "$1"
  fi
}

calculate_remaining() {
  local location=$(curl -s ipinfo.io | jq -r '.city + "," + .country')
  local api_url="https://muslimsalat.com/${location// /}/daily.json"
  local response=$(curl -s "$api_url")
  if ! echo "$response" | jq . >/dev/null 2>&1; then
    log "❌ Invalid response from API"
    echo "Prayer time data unavailable."
    return
  fi

  local now_ts=$(date +%s)
  local today_timings=$(echo "$response" | jq '.items[0]')
  local day_of_week=$(date "+%A")
  local is_dst=$(date +%Z | grep -qE 'EEST|CEST|DST' && echo 1 || echo 0)

  for prayer in fajr dhuhr asr maghrib isha; do
    local label="$prayer"
    [ "$prayer" = "dhuhr" ] && [ "$day_of_week" = "Friday" ] && label="jomoa"

    local raw_time=$(echo "$today_timings" | jq -r ".${prayer}")
    local prayer_ts=$(date -j -f "%Y-%m-%d %I:%M %p" "$(date +%F) $raw_time" +%s 2>/dev/null)

    if [ "$is_dst" -eq 1 ]; then
      prayer_ts=$((prayer_ts + 3600))
    fi

    if [ "$prayer_ts" -gt "$now_ts" ]; then
      local remaining=$((prayer_ts - now_ts))
      local h=$((remaining / 3600))
      local m=$(( (remaining % 3600) / 60 ))
      [ "$h" -gt 0 ] && echo "$h hours and $m minutes remaining until $label prayer." || echo "$m minutes remaining until $label prayer."
      return
    fi
  done

  echo "All prayers done for today."
}

start_alarm() {
  echo "$1|$2" >> "$ALARMS_FILE"
  echo "say -v $VOICE '⏰ Alarm $1 at $2'" | at "$2" 2>/dev/null
  log "✅ Alarm '$1' set at $2"
}

start_cdtimer() {
  IFS=":" read -r h m <<< "${2//:/ }"
  local seconds=$((10#$h * 3600 + 10#$m * 60))
  (
    sleep "$seconds"
    announce "⏳ Countdown timer $1 completed."
    log "⏳ Countdown timer '$1' completed."
  ) &
  log "⏳ Countdown timer '$1' started for $h hours and $m minutes."
}

declare -A TIMERS

handle_timer() {
  local now=$(date +%s)
  case "$2" in
    start)
      TIMERS["$1"]=$now
      log "⏱️ Timer '$1' started."
      ;;
    stop)
      if [ -n "${TIMERS[$1]}" ]; then
        local duration=$((now - ${TIMERS[$1]}))
        unset TIMERS["$1"]
        log "⏱️ Timer '$1' stopped after $duration seconds."
      else
        log "⚠️ Timer '$1' not found."
      fi
      ;;
    pause)
      log "⏸️ Pause not implemented yet for '$1'."
      ;;
    *)
      log "❓ Usage: timer name start|stop|pause"
      ;;
  esac
}

auto_announce() {
  local last_spoken_min=-1
  while true; do
    sleep 60
    [ "$MUTE" = "on" ] && continue
    msg=$(calculate_remaining)
    [[ "$msg" =~ ([0-9]+)\ minutes ]] && remaining_min=${BASH_REMATCH[1]} || remaining_min=0

    if [ "$remaining_min" -le $((SECONDS_ANNOUNCE / 60)) ]; then
      for ((s=SECONDS_ANNOUNCE; s>=1; s-=2)); do
        log "$s seconds remaining..."
        announce "$s seconds remaining..."
        sleep 2
      done
    elif [ "$remaining_min" -le "$MINUTES_ANNOUNCE" ]; then
      if (( remaining_min != last_spoken_min )); then
        log "$msg"
        announce "$msg"
        last_spoken_min=$remaining_min
      fi
    elif (( remaining_min % MINUTES_INTERVAL == 0 )) && (( remaining_min != last_spoken_min )); then
      log "$msg"
      announce "$msg"
      last_spoken_min=$remaining_min
    fi
  done
}

handle_command() {
  case "$1" in
    ar) LANGUAGE_MODE="ar"; set_voice; save_settings; log "✅ اللغة الآن: العربية" ;;
    en) LANGUAGE_MODE="en"; set_voice; save_settings; log "✅ Language set to English" ;;
    mute)
      [[ "$2" =~ ^(on|off)$ ]] && MUTE="$2" && save_settings && log "🔇 Mute set to $MUTE" || log "❓ Usage: mute on|off"
      ;;
    now)
      msg=$(calculate_remaining)
      log "$msg"
      announce "$msg"
      ;;
    alarm)
      [[ "$2" && "$3" ]] && start_alarm "$2" "$3" || log "❓ Usage: alarm name hh:mm"
      ;;
    cdtimer)
      [[ "$2" && "$3" ]] && start_cdtimer "$2" "$3" || log "❓ Usage: cdtimer name hh:mm"
      ;;
    timer)
      [[ "$2" && "$3" ]] && handle_timer "$2" "$3" || log "❓ Usage: timer name start|stop|pause"
      ;;
    play)
      if [[ "$2" == "azan" ]]; then
        if [ -f "$ADHAN_SOUND" ]; then
          afplay "$ADHAN_SOUND" >/dev/null 2>&1 &
        else
          log "❌ Azan file not found."
        fi
      fi
      ;;
    persist) save_settings; log "✅ Settings persisted." ;;
    exit|quit) log "👋 Exiting..."; exit 0 ;;
    *) log "❓ Unknown command: $1" ;;
  esac
}

# 🚀 Main execution
load_settings
set_voice

msg=$(calculate_remaining)
log "$msg"
announce "$msg"

auto_announce &

while true; do
  read -rp ">> " cmd arg1 arg2
  handle_command "$cmd" "$arg1" "$arg2"
done