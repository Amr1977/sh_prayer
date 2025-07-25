#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export TEST_MODE=1
  export SETTINGS_FILE="/tmp/prayer_settings.conf"
  export LOG_FILE="/tmp/prayer_test.log"
  > "$LOG_FILE"
}

@test "Default language is English" {
  run bash prayer.sh en
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Language set to English" ]]
}

@test "Set language to Arabic" {
  run bash prayer.sh ar
  [[ "$output" =~ "اللغة الآن" ]]
}

@test "Mute on and off" {
  run bash prayer.sh mute on
  [[ "$output" =~ "Mute set to on" ]]
  run bash prayer.sh mute off
  [[ "$output" =~ "Mute set to off" ]]
}

@test "Set interval to 5" {
  run bash prayer.sh set interval 5
  [[ "$output" =~ "MINUTES_INTERVAL set to 5" ]]
}

@test "Set announce minutes to 15" {
  run bash prayer.sh set announce minutes 15
  [[ "$output" =~ "MINUTES_ANNOUNCE set to 15" ]]
}

@test "Set announce seconds to 30" {
  run bash prayer.sh set announce seconds 30
  [[ "$output" =~ "SECONDS_ANNOUNCE set to 30" ]]
}

@test "Show settings" {
  run bash prayer.sh show settings
  [[ "$output" =~ "MINUTES_INTERVAL" ]]
}

@test "Play azan with missing file" {
  run bash prayer.sh play azan
  [[ "$output" =~ "Azan file not found" ]]
}

@test "Unknown command" {
  run bash prayer.sh foobar
  [[ "$output" =~ "Unknown command" ]]
}
