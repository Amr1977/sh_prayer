#!/bin/bash

VOICE="-v mb-us2"
PITCH="-p 30"
SPEED="-s 110"

echo "Detecting your location..."
location=$(curl -s ipinfo.io | jq -r '.city + "," + .country')
echo "Location: $location"

echo "Fetching prayer times..."
API_URL="https://muslimsalat.com/${location// /}/daily.json"
response=$(curl -s "$API_URL")

if ! echo "$response" | jq . >/dev/null 2>&1; then
  echo "❌ Invalid response from API"
  exit 1
fi

today_timings=$(echo "$response" | jq '.items[0]')
now_ts=$(date +%s)
is_dst=$(date +%Z | grep -qE 'EEST|CEST|DST' && echo 1 || echo 0)

next_prayer=""
next_time=""
target_ts=""

for prayer in fajr dhuhr asr maghrib isha; do
  raw_time=$(echo "$today_timings" | jq -r ".${prayer}")
  adjusted_time="$raw_time"
  if [ "$is_dst" -eq 1 ]; then
    adjusted_time=$(date -d "$raw_time 1 hour" +"%I:%M %p")
  fi

  prayer_time_24=$(date -d "$(date +%F) $adjusted_time" +"%H:%M")
  full_time_local="$(date +%F) $prayer_time_24"
  prayer_ts=$(date -d "$full_time_local" +%s 2>/dev/null)

  echo "→ $prayer: original=$raw_time adjusted=$adjusted_time => $prayer_time_24"

  if [ "$prayer_ts" -gt "$now_ts" ]; then
    next_prayer="$prayer"
    next_time="$prayer_time_24"
    target_ts="$prayer_ts"
    break
  fi
done

if [ -z "$next_prayer" ]; then
  echo "No more prayers today."
  exit 0
fi

echo "Next prayer: $next_prayer at $next_time"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOORBELL_SOUND="$SCRIPT_DIR/bell.wav"

speak_remaining() {
  remaining_sec=$1
  h=$(( remaining_sec / 3600 ))
  m=$(( (remaining_sec % 3600) / 60 ))

  if [ "$h" -gt 0 ]; then
    message="$h hours and $m minutes remaining until $next_prayer prayer."
  else
    message="$m minutes remaining until $next_prayer prayer."
  fi

  if [ -f "$DOORBELL_SOUND" ]; then
    aplay "$DOORBELL_SOUND"
  fi

  echo "$message"
  espeak $VOICE $PITCH $SPEED "$message"
}

# ✅ Initial speak
initial_remaining=$(( target_ts - now_ts ))
speak_remaining "$initial_remaining"

last_spoken_minute=-1

while true; do
  now_ts=$(date +%s)
  remaining=$(( target_ts - now_ts ))
  remaining_min=$(( remaining / 60 ))

  if [ "$remaining" -le 0 ]; then
    espeak $VOICE $PITCH $SPEED "It is time for $next_prayer prayer."
    echo "It is time for $next_prayer prayer."
    break

  elif [ "$remaining" -le 60 ]; then
    for ((s=remaining; s>=1; s-=2)); do
      echo "$s seconds remaining..."
      espeak $VOICE $PITCH $SPEED "$s"
      sleep 2
    done
    espeak $VOICE $PITCH $SPEED "It is time for $next_prayer prayer."
    break

  elif [ "$remaining" -le 1200 ]; then
    speak_remaining "$remaining"
    sleep 60

  else
    if (( remaining_min % 10 == 0 && remaining_min != last_spoken_minute )); then
      speak_remaining "$remaining"
      last_spoken_minute=$remaining_min
    fi
    sleep 60
  fi
done