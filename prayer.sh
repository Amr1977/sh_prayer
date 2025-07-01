#!/bin/bash

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
  echo "$json" | jq -r ".items[0].$key"
}

calculate_remaining() {
  local now_ts=$(date +%s)
  local response=$(fetch_prayer_times)
  local day_of_week=$(date "+%A")
  local is_dst=$(date +%Z | grep -qE 'EEST|CEST|DST' && echo 1 || echo 0)

  local maghrib=$(get_prayer_time "$response" "maghrib")
  local isha=$(get_prayer_time "$response" "isha")
  local fajr=$(get_prayer_time "$response" "fajr")

  local maghrib_ts=$(date -d "$(date +%F) $maghrib" +%s)
  local isha_ts=$(date -d "$(date +%F) $isha" +%s)
  local fajr_ts=$(date -d "$(date -d tomorrow +%F) $fajr" +%s)

  [ "$is_dst" -eq 1 ] && {
    maghrib_ts=$((maghrib_ts + 3600))
    isha_ts=$((isha_ts + 3600))
    fajr_ts=$((fajr_ts + 3600))
  }

  local night_duration=$((fajr_ts - maghrib_ts))
  local last_third_start=$((maghrib_ts + 2 * night_duration / 3))

  if (( now_ts < maghrib_ts )); then
    # Regular daytime: announce next prayer
    for prayer in fajr dhuhr asr maghrib isha; do
      local raw=$(get_prayer_time "$response" "$prayer")
      local ts=$(date -d "$(date +%F) $raw" +%s)
      [ "$is_dst" -eq 1 ] && ts=$((ts + 3600))
      if (( ts > now_ts )); then
        local diff=$((ts - now_ts))
        local h=$(( diff / 3600 ))
        local m=$(( (diff % 3600) / 60 ))
        return_msg "$prayer" "$h" "$m"
        return
      fi
    done
  elif (( now_ts >= isha_ts && now_ts < last_third_start )); then
    local diff=$((last_third_start - now_ts))
    local h=$(( diff / 3600 ))
    local m=$(( (diff % 3600) / 60 ))
    echo "Last third of the night begins in $h hours and $m minutes."
    return
  elif (( now_ts >= last_third_start && now_ts < fajr_ts )); then
    local diff=$((fajr_ts - now_ts))
    local h=$(( diff / 3600 ))
    local m=$(( (diff % 3600) / 60 ))
    echo "Fajr prayer in $h hours and $m minutes."
    return
  else
    echo "No upcoming prayer found."
  fi
}

return_msg() {
  local label="$1" h="$2" m="$3"
  if (( h > 0 )); then
    echo "$label prayer in $h hours and $m minutes."
  else
    echo "$label prayer in $m minutes."
  fi
}

auto_announce() {
  local last_spoken_min=-1
  local last_spoken_hr=-1
  while true; do
    sleep 60
    [ "$MUTE" = "on" ] && continue

    local msg=$(calculate_remaining)
    local remaining_min=0
    local remaining_hr=0

    if [[ "$msg" =~ ([0-9]+)\ hours\ and\ ([0-9]+)\ minutes ]]; then
      remaining_hr="${BASH_REMATCH[1]}"
      remaining_min="${BASH_REMATCH[2]}"
    elif [[ "$msg" =~ ([0-9]+)\ minutes ]]; then
      remaining_hr=0
      remaining_min="${BASH_REMATCH[1]}"
    else
      continue
    fi

    if (( remaining_min == last_spoken_min && remaining_hr == last_spoken_hr )); then
      continue
    fi

    if (( remaining_hr > 0 )); then
      if (( remaining_min % MINUTES_INTERVAL == 0 )); then
        log "$msg"
        announce "$msg"
        last_spoken_min=$remaining_min
        last_spoken_hr=$remaining_hr
      fi
      continue
    fi

    if (( remaining_min <= SECONDS_ANNOUNCE / 60 )); then
      for ((s=SECONDS_ANNOUNCE; s>=1; s-=2)); do
        log "$s seconds remaining..."
        announce "$s seconds remaining..."
        sleep 2
      done
      continue
    fi

    if (( remaining_min <= MINUTES_ANNOUNCE )); then
      log "$msg"
      announce "$msg"
      last_spoken_min=$remaining_min
      last_spoken_hr=$remaining_hr
      continue
    fi

    if (( remaining_min % MINUTES_INTERVAL == 0 )); then
      log "$msg"
      announce "$msg"
      last_spoken_min=$remaining_min
      last_spoken_hr=$remaining_hr
    fi
  done
}

handle_command() {
  case "$1" in
    ar|en)
      LANGUAGE_MODE="$1"
      set_voice
      save_settings
      log "✅ Language set to $LANGUAGE_MODE"
      ;;
    mute)
      [[ "$2" =~ ^(on|off)$ ]] && MUTE="$2" && save_settings && log "🔇 Mute set to $MUTE"
      ;;
    now)
      local msg=$(calculate_remaining)
      log "$msg"
      announce "$msg"
      ;;
    play)
      [[ "$2" == "azan" && -f "$ADHAN_SOUND" ]] && mpv "$ADHAN_SOUND" >/dev/null 2>&1 &
      ;;
    v)
      [[ "$2" == "+" ]] && amixer sset Master 5%+ >/dev/null && echo "🔊 Volume increased"
      [[ "$2" == "-" ]] && amixer sset Master 5%- >/dev/null && echo "🔉 Volume decreased"
      ;;
    set)
      case "$2" in
        interval)
          MINUTES_INTERVAL="$3"; save_settings; log "🔁 MINUTES_INTERVAL=$3"
          ;;
        announce)
          [[ "$3" == "minutes" ]] && MINUTES_ANNOUNCE="$4"
          [[ "$3" == "seconds" ]] && SECONDS_ANNOUNCE="$4"
          save_settings
          ;;
      esac
      ;;
    show)
      echo -e "⏱️ Current settings:\n- MINUTES_INTERVAL=$MINUTES_INTERVAL\n- MINUTES_ANNOUNCE=$MINUTES_ANNOUNCE\n- SECONDS_ANNOUNCE=$SECONDS_ANNOUNCE"
      ;;
    reload)
      load_settings; set_voice; log "🔁 Settings reloaded."
      ;;
    persist)
      save_settings; log "✅ Settings persisted."
      ;;
     times)
      local response=$(fetch_prayer_times)
      local date=$(echo "$response" | jq -r '.items[0].date_for')
      local is_dst=$(date +%Z | grep -qE 'EEST|CEST|DST' && echo 1 || echo 0)

      echo "📅 Prayer Times for $date:"

      declare -A times
      for p in fajr dhuhr asr maghrib isha; do
        local raw=$(get_prayer_time "$response" "$p")
        local ts=$(date -d "$(date +%F) $raw" +%s)
        [ "$is_dst" -eq 1 ] && ts=$((ts + 3600))
        times[$p]=$ts
        local adj=$(date -d "@$ts" +"%I:%M %p" | sed 's/^0//')
        printf "🕒 %7s: %s\n" "$(tr 'a-z' 'A-Z' <<< "$p")" "$adj"
      done

      # Fetch tomorrow's fajr for accurate night duration
      local location=$(curl -s ipinfo.io | jq -r '.city + "," + .country')
      local tomorrow=$(date -d "tomorrow" +%Y-%m-%d)
      local api_url="https://muslimsalat.com/${location// /}/$tomorrow.json"
      local next_day=$(curl -s "$api_url")

      local fajr_tomorrow=$(echo "$next_day" | jq -r ".items[0].fajr")
      local fajr_ts=$(date -d "$tomorrow $fajr_tomorrow" +%s)
      [ "$is_dst" -eq 1 ] && fajr_ts=$((fajr_ts + 3600))

      local night_duration=$((fajr_ts - times[maghrib]))
      local last_third_start=$((times[maghrib] + 2 * night_duration / 3))
      local last_third_str=$(date -d "@$last_third_start" +"%I:%M %p" | sed 's/^0//')
      echo "🌙 LAST THIRD: $last_third_str"
      ;;
    help)
  echo -e "🆘 Commands:\n\
  ar | en                   - Switch language\n\
  mute on|off              - Toggle mute\n\
  now                      - Show remaining time\n\
  times                    - Show today's prayer times\n\
  play azan                - Play azan audio\n\
  v +|-                    - Volume up/down\n\
  set interval N           - Set interval in minutes\n\
  set announce minutes|seconds N - Fine-tune alerts\n\
  show settings            - Display settings\n\
  reload                   - Reload settings\n\
  persist                  - Save current settings\n\
  help                     - Show this list\n\
  exit|quit                - Exit script"
  ;;

    exit|quit) log "👋 Exiting..."; exit 0 ;;
    *) log "❓ Unknown command: $1" ;;
  esac
}

# Startup
load_settings
set_voice
msg=$(calculate_remaining)
log "$msg"
announce "$msg"

# Lock check
if [ -e "$LOCKFILE" ]; then
  echo "🔒 Another instance is already running. Exiting."
  exit 1
else
  touch "$LOCKFILE"
  trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT
fi

auto_announce &

if [[ "$#" -gt 0 ]]; then
  handle_command "$@"
  exit 0
fi

while true; do
  read -rp ">> " cmd arg1 arg2 arg3
  handle_command "$cmd" "$arg1" "$arg2" "$arg3"
done