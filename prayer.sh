#!/bin/bash

ensure_dependencies() {
  # Main dependencies
  local pkgs=(mpv espeak jq curl amixer notify-send)
  # For voices: mbrola and mbrola voices for US English and Arabic
  local voice_pkgs=(mbrola mbrola-us2 mbrola-ar1)
  local missing=()
  local missing_voice=()

  # Check main dependencies
  for pkg in "${pkgs[@]}"; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  # Check mbrola voices (only if espeak is present)
  if command -v espeak >/dev/null 2>&1; then
    for vpkg in "${voice_pkgs[@]}"; do
      dpkg -s "$vpkg" >/dev/null 2>&1 || missing_voice+=("$vpkg")
    done
  fi

  if [ "${#missing[@]}" -gt 0 ] || [ "${#missing_voice[@]}" -gt 0 ]; then
    echo "🔧 Installing missing packages: ${missing[*]} ${missing_voice[*]}"
    if command -v apt-get >/dev/null 2>&1; then
      # Check for dpkg lock
      if sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
        echo "❌ Package manager is busy. Please wait for other installations to finish and rerun this script."
        exit 1
      fi
      sudo apt-get update
      if [ "${#missing[@]}" -gt 0 ]; then
        sudo apt-get install -y "${missing[@]}"
      fi
      if [ "${#missing_voice[@]}" -gt 0 ]; then
        sudo apt-get install -y "${missing_voice[@]}"
      fi
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y "${missing[@]}" "${missing_voice[@]}"
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Sy --noconfirm "${missing[@]}" "${missing_voice[@]}"
    else
      echo "❌ No supported package manager found. Please install: ${missing[*]} ${missing_voice[*]}"
      exit 1
    fi
  fi
}

ensure_dependencies

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




play_azan() {
  [[ -f "$ADHAN_SOUND" ]] && mpv "$ADHAN_SOUND" >/dev/null 2>&1 &
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

get_hijri_date() {
  local today=$(date +%Y-%m-%d)
  local year month day
  year=$(date +%Y)
  month=$(date +%m)
  day=$(date +%d)
  # Fetch the month's Hijri calendar
  local hijri_json=$(curl -s "https://api.aladhan.com/v1/gToHCalendar/$month/$year?adjustment=0")
  if [[ -z "$hijri_json" ]]; then
    echo "🗓️ Hijri Date: (unavailable - API unreachable)"
    return
  fi
  # Find today's Gregorian date in the calendar
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

calculate_remaining() {
  local now_ts=$(date +%s)
  local response=$(fetch_prayer_times)
  local day_of_week=$(date "+%A")
  local is_dst=$(date +%Z | grep -qE 'EEST|CEST|DST' && echo 1 || echo 0)

  local fajr=$(get_prayer_time "$response" "fajr")
  local today=$(date +%F)
  local fajr_today_ts=$(date -d "$today $fajr" +%s)
  local fajr_tomorrow_ts=$(date -d "$(date -d tomorrow +%F) $fajr" +%s)

  if (( now_ts < fajr_today_ts )); then
    # After midnight but before today's Fajr: use yesterday's Maghrib/Isha and today's Fajr
    local yest=$(date -d "yesterday" +%F)
    local maghrib=$(get_prayer_time "$response" "maghrib")
    local isha=$(get_prayer_time "$response" "isha")
    local maghrib_ts=$(date -d "$yest $maghrib" +%s)
    local isha_ts=$(date -d "$yest $isha" +%s)
    local fajr_ts=$fajr_today_ts
  else
    # After today's Fajr: use today's Maghrib/Isha and tomorrow's Fajr
    local maghrib=$(get_prayer_time "$response" "maghrib")
    local isha=$(get_prayer_time "$response" "isha")
    local maghrib_ts=$(date -d "$today $maghrib" +%s)
    local isha_ts=$(date -d "$today $isha" +%s)
    local fajr_ts=$fajr_tomorrow_ts
  fi
  [ "$is_dst" -eq 1 ] && {
    maghrib_ts=$((maghrib_ts + 3600))
    isha_ts=$((isha_ts + 3600))
    fajr_ts=$((fajr_ts + 3600))
  }

  local night_duration=$((fajr_ts - maghrib_ts))
  local last_third_start=$((maghrib_ts + 2 * night_duration / 3))
  # echo "DEBUG: now_ts=$now_ts maghrib_ts=$maghrib_ts isha_ts=$isha_ts fajr_ts=$fajr_ts last_third_start=$last_third_start" >&2
  # echo "DEBUG: now=$(date -d @$now_ts) maghrib=$(date -d @$maghrib_ts) isha=$(date -d @$isha_ts) fajr=$(date -d @$fajr_ts) last_third_start=$(date -d @$last_third_start)" >&2

  if (( now_ts < isha_ts )); then
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
  local time_str
  time_str=$(format_time "$h" "$m")
  echo "Last third of the night begins in $time_str."
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

format_time() {
  local h="$1"
  local m="$2"
  local out=""
  if (( h > 0 )); then
    out="$h hour"
    (( h > 1 )) && out+="s"
  fi
  if (( m > 0 )); then
    [[ -n "$out" ]] && out+=" and "
    out+="$m minute"
    (( m > 1 )) && out+="s"
  fi
  echo "$out"
}

return_msg() {
  local label="$1" h="$2" m="$3"
  local time_str
  time_str=$(format_time "$h" "$m")
  if [[ -n "$time_str" ]]; then
    echo "$label prayer in $time_str."
  else
    echo "It's time for $label prayer!"
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

    # Match "Last third of the night begins in X hours and Y minutes" first
    if [[ "$msg" =~ Last\ third\ of\ the\ night\ begins\ in\ ([0-9]+)\ hours\ and\ ([0-9]+)\ minutes ]]; then
      remaining_hr="${BASH_REMATCH[1]}"
      remaining_min="${BASH_REMATCH[2]}"
    elif [[ "$msg" =~ ([0-9]+)\ hours\ and\ ([0-9]+)\ minutes ]]; then
      remaining_hr="${BASH_REMATCH[1]}"
      remaining_min="${BASH_REMATCH[2]}"
      if (( remaining_hr == 0 && remaining_min == 0 )); then
        log "🕌 It's prayer time! Playing azan."
        play_azan
        last_spoken_min=$remaining_min
        last_spoken_hr=$remaining_hr
        continue
      fi
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
        last_spoken_min=$remaining_min
        last_spoken_hr=$remaining_hr
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

show_prayer_times() {
  local response=$(fetch_prayer_times)
  local date=$(echo "$response" | jq -r '.items[0].date_for')
  local is_dst=$(date +%Z | grep -qE 'EEST|CEST|DST' && echo 1 || echo 0)

  echo "📅 Prayer Times for $date:"
  get_hijri_date
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
    hijri)
      get_hijri_date
      ;;
    reload)
      load_settings; set_voice; log "🔁 Settings reloaded."
      ;;
    persist)
      save_settings; log "✅ Settings persisted."
      ;;
     times)
      show_prayer_times
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
show_prayer_times
get_hijri_date
msg=$(calculate_remaining)
log "$msg"
announce "$msg"

if [ -e "$LOCKFILE" ]; then
  LOCKPID=$(cat "$LOCKFILE")
  if [ -n "$LOCKPID" ] && kill -0 "$LOCKPID" 2>/dev/null; then
    echo "🔒 Another instance (PID $LOCKPID) is already running. Exiting."
    exit 1
  else
    echo "⚠️ Stale lock file found."
    read -p "Do you want to delete the lock file? [y/N]: " yn
    case "$yn" in
      [Yy]*) rm -f "$LOCKFILE"; echo "✅ Lock file deleted." ;;
      *) echo "Exiting."; exit 1 ;;
    esac
  fi
fi

echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT


auto_announce &

if [[ "$#" -gt 0 ]]; then
  handle_command "$@"
  exit 0
fi

while true; do
  read -rp ">> " cmd arg1 arg2 arg3
  handle_command "$cmd" "$arg1" "$arg2" "$arg3"
done