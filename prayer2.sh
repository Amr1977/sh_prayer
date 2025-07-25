
#!/bin/bash

VERSION="1.0.0"

LANGUAGE_MODE="en"
VOICE="mb-us2"
PITCH="-p 20"
SPEED="-s 100"
MUTE="off"

SECONDS_ANNOUNCE=60
MINUTES_ANNOUNCE=30
MINUTES_INTERVAL=10
DISABLE_NOTIFY=false

SETTINGS_FILE="$HOME/.prayer_settings.conf"
PRAYER_CACHE_FILE="/tmp/prayer_times_$(date +%F).json"
LOCKFILE="/tmp/prayer_notify.lock"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/prayer.log"
OUT_LOG_FILE="$SCRIPT_DIR/prayer_out.log"
DOORBELL_SOUND="$SCRIPT_DIR/bell.wav"
ADHAN_SOUND="$SCRIPT_DIR/azan.mp3"

load_settings() { [ -f "$SETTINGS_FILE" ] && source "$SETTINGS_FILE"; }

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
DISABLE_NOTIFY=$DISABLE_NOTIFY
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
  log "Besmillah"
  espeak -v "$VOICE" "Besmillah" $PITCH $SPEED >/dev/null 2>&1
  log "Voice set to VOICE: $VOICE PITCH: $PITCH SPEED: $SPEED"
}

log() {
  local ts msg="$1"
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$ts] $msg" | tee -a "$LOG_FILE"
}

announce() {
  [ "$MUTE" = "on" ] && log "🔇 Skipping announcement due to mute" && return
  $DISABLE_NOTIFY || notify-send "Prayer Notifier" "$1"
  [ "$LANGUAGE_MODE" = "ar" ] && return
  espeak -v "$VOICE" "$1" $PITCH $SPEED >/dev/null 2>&1
}

fetch_prayer_times() {
  if [ ! -f "$PRAYER_CACHE_FILE" ]; then
    local location=$(curl -s ipinfo.io | jq -r '.city + "," + .country')
    local api_url="https://muslimsalat.com/${location// /}/daily.json"
    curl -s "$api_url" > "$PRAYER_CACHE_FILE"
  fi
  cat "$PRAYER_CACHE_FILE"
}

get_prayer_time() {
  local json="$1" key="$2"
  local val=$(echo "$json" | jq -r ".items[0].$key")
  if [[ "$val" == "null" || -z "$val" ]]; then
    log "⚠️ Prayer time for $key not found or invalid"
    echo "00:00"
  else
    echo "$val"
  fi
}

get_hijri_date() {
  local today=$(date +%Y-%m-%d)
  local year month day
  year=$(date +%Y)
  month=$(date +%m)
  day=$(date +%d)
  local hijri_json=$(curl -s "https://api.aladhan.com/v1/gToHCalendar/$month/$year?adjustment=0")
  if [[ -z "$hijri_json" ]]; then
    echo "🗓️ Hijri Date: (unavailable - API unreachable)"
    return
  fi
  local idx=$(echo "$hijri_json" | jq ".data | to_entries[] | select(.value.gregorian.date==\"$today\") | .key")
  if [[ -z "$idx" ]]; then
    echo "🗓️ Hijri Date: (unavailable - not found)"
    return
  fi
  local hijri_day=$(echo "$hijri_json" | jq -r ".data[$idx].hijri.day")
  local hijri_month=$(echo "$hijri_json" | jq -r ".data[$idx].hijri.month.en")
  local hijri_year=$(echo "$hijri_json" | jq -r ".data[$idx].hijri.year")
  if [[ -z "$hijri_day" || -z "$hijri_month" || -z "$hijri_year" || "$hijri_day" == "null" || "$hijri_month" == "null" || "$hijri_year" == "null" ]]; then
    echo "🗓️ Hijri Date: (unavailable - parsing error)"
    return
  fi
  echo "🗓️ Hijri Date: $hijri_day $hijri_month $hijri_year AH"
}

play_azan() {
  [[ -f "$ADHAN_SOUND" ]] && mpv "$ADHAN_SOUND" >/dev/null 2>&1 &
}

handle_command() {
  case "$1" in
    --version|-v)
      echo "sh_prayer version $VERSION"
      ;;
    *)
      echo "Normal command flow here..."
      ;;
  esac
}

# Simple entry to test version
if [[ "$1" == "--version" || "$1" == "-v" ]]; then
  handle_command "$1"
  exit 0
fi
