#!/bin/bash

LANGUAGE_MODE="en"
VOICE="Alex"
MUTE="off"
SETTINGS_FILE="$HOME/.prayer_settings.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/prayer.log"
ADHAN_SOUND="$SCRIPT_DIR/adhan.mp3"

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
  say -v "$VOICE" "Voice set to $VOICE"
}

log() {
  local msg="$1"
  local ts=$(date "+%Y-%m-%d %H:%M:%S")
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

  for prayer in fajr dhuhr asr maghrib isha; do
    local label="$prayer"
    if [ "$prayer" = "dhuhr" ] && [ "$day_of_week" = "Friday" ]; then
      label="jomoa"
    fi

    local raw_time=$(echo "$today_timings" | jq -r ".${prayer}")
    local prayer_ts=$(date -j -f "%Y-%m-%d %I:%M %p" "$(date +%F) $raw_time" +%s 2>/dev/null)

    if [ "$prayer_ts" -gt "$now_ts" ]; then
      local remaining=$((prayer_ts - now_ts))
      local h=$(( remaining / 3600 ))
      local m=$(( (remaining % 3600) / 60 ))
      if [ "$h" -gt 0 ]; then
        echo "$h hours and $m minutes remaining until $label prayer."
      else
        echo "$m minutes remaining until $label prayer."
      fi
      return
    fi
  done

  echo "All prayers done for today."
}

handle_command() {
  case "$1" in
    ar)
      LANGUAGE_MODE="ar"
      set_voice
      save_settings
      log "✅ اللغة الآن: العربية"
      ;;
    en)
      LANGUAGE_MODE="en"
      set_voice
      save_settings
      log "✅ Language set to English"
      ;;
    mute)
      if [[ "$2" == "on" || "$2" == "off" ]]; then
        MUTE="$2"
        save_settings
        log "🔇 Mute set to $MUTE"
      else
        log "❓ Usage: mute on|off"
      fi
      ;;
    now)
      msg=$(calculate_remaining)
      log "$msg"
      announce "$msg"
      ;;
    play)
      if [[ "$2" == "azan" ]]; then
        if [ -f "$ADHAN_SOUND" ]; then
          afplay "$ADHAN_SOUND"
          log "📢 Playing Azan"
        else
          log "❌ Azan file not found: $ADHAN_SOUND"
        fi
      else
        log "❓ Usage: play azan"
      fi
      ;;
    persist)
      save_settings
      log "✅ Settings persisted."
      ;;
    exit|quit)
      log "👋 Exiting..."
      exit 0
      ;;
    *)
      log "❓ Unknown command: $1"
      ;;
  esac
}

load_settings
set_voice
while true; do
  read -rp ">> " cmd arg1 arg2
  handle_command "$cmd" "$arg1" "$arg2"
done
