#!/bin/bash

LANGUAGE_MODE="en"
VOICE="mb-us2"
PITCH="-p 20"
SPEED="-s 100"
MUTE="off"

SECONDS_ANNOUNCE=60
MINUTES_ANNOUNCE=20
MINUTES_INTERVAL=10

SETTINGS_FILE="$HOME/.prayer_settings.conf"
ALARMS_FILE="$HOME/.prayer_alarms.conf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/prayer.log"
OUT_LOG_FILE="$SCRIPT_DIR/prayer_out.log"
DOORBELL_SOUND="$SCRIPT_DIR/bell.wav"
ADHAN_SOUND="$SCRIPT_DIR/azan.mp3"

load_settings() {
  [ -f "$SETTINGS_FILE" ] && source "$SETTINGS_FILE"
}

save_settings() {
  cat > "$SETTINGS_FILE" <<EOF
LANGUAGE_MODE="$LANGUAGE_MODE"
VOICE="$VOICE"
PITCH="$PITCH"
SPEED="$SPEED"
MUTE="$MUTE"
SECONDS_ANNOUNCE=$SECONDS_ANNOUNCE
MINUTES_ANNOUNCE=$MINUTES_ANNOUNCE
MINUTES_INTERVAL=$MINUTES_INTERVAL
EOF
}

set_voice() {
  if [ "$LANGUAGE_MODE" = "ar" ]; then
    VOICE="ar"
    PITCH="-p 50"
    SPEED="-s 110"
  else
    VOICE="mb-us2"
    PITCH="-p 20"
    SPEED="-s 100"
  fi
  espeak -v "$VOICE" "Voice set to $VOICE" $PITCH $SPEED >/dev/null 2>&1
  log "✅ Voice set to $VOICE"
}

log() {
  local ts msg="$1"
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$ts] $msg" | tee -a "$LOG_FILE"
}

announce() {
  if [ "$MUTE" = "off" ]; then
    notify-send "Prayer Notifier" "$1"
    espeak -v "$VOICE" "$1" $PITCH $SPEED
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
    local ts=$(date -d "$(date +%F) $raw_time" +%s 2>/dev/null)
    [ "$is_dst" -eq 1 ] && ts=$((ts + 3600))

    if [ "$ts" -gt "$now_ts" ]; then
      local remaining=$((ts - now_ts))
      local h=$((remaining / 3600))
      local m=$(( (remaining % 3600) / 60 ))
      [ "$h" -gt 0 ] && echo "$h hours and $m minutes remaining until $label prayer." || echo "$m minutes remaining until $label prayer."
      return
    fi
  done

  echo "All prayers done for today."
}

auto_announce() {
  local last_spoken_min=-1
  while true; do
    sleep 60
    [ "$MUTE" = "on" ] && continue

    local msg=$(calculate_remaining)
    local remaining_min=0
    local remaining_hr=0

    # Extract hours and minutes
    if [[ "$msg" =~ ([0-9]+)\ hours\ and\ ([0-9]+)\ minutes ]]; then
      remaining_hr="${BASH_REMATCH[1]}"
      remaining_min="${BASH_REMATCH[2]}"
    elif [[ "$msg" =~ ([0-9]+)\ minutes ]]; then
      remaining_hr=0
      remaining_min="${BASH_REMATCH[1]}"
    else
      continue
    fi

    # Announce at every MINUTES_INTERVAL even if hours > 0
    if (( remaining_min % MINUTES_INTERVAL == 0 )) && (( remaining_min != last_spoken_min )); then
      log "$msg"
      announce "$msg"
      last_spoken_min=$remaining_min
      continue
    fi

    # Only do minute or second countdown when we're close
    if (( remaining_hr == 0 )); then
      if (( remaining_min <= SECONDS_ANNOUNCE / 60 )); then
        for ((s=SECONDS_ANNOUNCE; s>=1; s-=2)); do
          log "$s seconds remaining..."
          announce "$s seconds remaining..."
          sleep 2
        done
      elif (( remaining_min <= MINUTES_ANNOUNCE )) && (( remaining_min != last_spoken_min )); then
        log "$msg"
        announce "$msg"
        last_spoken_min=$remaining_min
      fi
    fi
  done
}

record_out_entry() {
  local location=$(curl -s ipinfo.io | jq -r '.city + "," + .country')
  local api_url="https://muslimsalat.com/${location// /}/daily.json"
  local response=$(curl -s "$api_url")
  local now_ts=$(date +%s)
  local today_timings=$(echo "$response" | jq '.items[0]')
  local day_of_week=$(date "+%A")
  local is_dst=$(date +%Z | grep -qE 'EEST|CEST|DST' && echo 1 || echo 0)

  for prayer in fajr dhuhr asr maghrib isha; do
    local label="$prayer"
    [ "$prayer" = "dhuhr" ] && [ "$day_of_week" = "Friday" ] && label="jomoa"

    local raw_time=$(echo "$today_timings" | jq -r ".${prayer}")
    local ts=$(date -d "$(date +%F) $raw_time" +%s 2>/dev/null)
    [ "$is_dst" -eq 1 ] && ts=$((ts + 3600))

    if (( now_ts < ts )); then
      local diff=$((ts - now_ts))
      local msg="⏳ OUT for $label prayer, $((diff / 60)) minutes before azan"
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$OUT_LOG_FILE"
      log "$msg"
      return
    elif (( now_ts >= ts && now_ts - ts < 3600 )); then
      local diff=$((now_ts - ts))
      local msg="✅ OUT for $label prayer, $((diff / 60)) minutes since azan"
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$OUT_LOG_FILE"
      log "$msg"
      return
    fi
  done

  log "⚠️ Could not determine current prayer time."
}

handle_command() {
  case "$1" in
    ar) LANGUAGE_MODE="ar"; set_voice; save_settings; log "✅ اللغة الآن: العربية" ;;
    en) LANGUAGE_MODE="en"; set_voice; save_settings; log "✅ Language set to English" ;;
    mute)
      [[ "$2" =~ ^(on|off)$ ]] && MUTE="$2" && save_settings && log "🔇 Mute set to $MUTE" || log "❓ Usage: mute on|off"
      ;;
    now)
      local msg=$(calculate_remaining)
      log "$msg"
      announce "$msg"
      ;;
    play)
      if [[ "$2" == "azan" && -f "$ADHAN_SOUND" ]]; then
        mpv "$ADHAN_SOUND" >/dev/null 2>&1 &
      else
        log "❌ Azan file not found."
      fi
      ;;
    v)
      [[ "$2" == "+" ]] && amixer sset Master 5%+ > /dev/null && echo "🔊 Volume increased"
      [[ "$2" == "-" ]] && amixer sset Master 5%- > /dev/null && echo "🔉 Volume decreased"
      ;;
    set)
      case "$2" in
        interval)
          MINUTES_INTERVAL="$3"
          log "🔁 MINUTES_INTERVAL set to $3"
          save_settings
          ;;
        announce)
          [[ "$3" == "minutes" ]] && MINUTES_ANNOUNCE="$4" && log "🕐 MINUTES_ANNOUNCE set to $4" && save_settings
          [[ "$3" == "seconds" ]] && SECONDS_ANNOUNCE="$4" && log "⏱️ SECONDS_ANNOUNCE set to $4" && save_settings
          ;;
        *)
          log "❓ Usage: set interval N | set announce minutes|seconds N"
          ;;
      esac
      ;;
    show)
      [[ "$2" == "settings" ]] && echo -e "⏱️ Current settings:\n- MINUTES_INTERVAL=$MINUTES_INTERVAL\n- MINUTES_ANNOUNCE=$MINUTES_ANNOUNCE\n- SECONDS_ANNOUNCE=$SECONDS_ANNOUNCE"
      ;;
    out)
      record_out_entry
      ;;
    persist)
      save_settings
      log "✅ Settings persisted."
      ;;
    exit|quit)
      log "👋 Exiting..."; exit 0 ;;
    *)
      log "❓ Unknown command: $1"
      ;;
  esac
}

# 🚀 Start
load_settings
set_voice
msg=$(calculate_remaining)
log "$msg"
announce "$msg"
auto_announce &

while true; do
  read -rp ">> " cmd arg1 arg2 arg3
  handle_command "$cmd" "$arg1" "$arg2" "$arg3"
done