# 🕌 Prayer Time Notifier (Bash Script for Linux & macOS)

A lightweight and reliable Bash script that **announces upcoming Muslim prayer times** using **text-to-speech (TTS)** and optional bell sound alerts. It automatically detects your location and fetches accurate prayer times via the [MuslimSalat API](https://muslimsalat.com).

> 💡 Perfect for use in terminal dashboards, automation via `cron`, or running in the background on your Linux or macOS system.

---

## 🌟 Features

- 📍 Auto-detects your location via [IPInfo](https://ipinfo.io/)
- 🕌 Fetches accurate prayer times using [MuslimSalat](https://muslimsalat.com/)
- 🕐 Announces remaining time using TTS with optional bell sound
- 🕰️ Smart Daylight Saving Time adjustment
- ⏳ Countdown announcements in the final minute
- ✅ Cross-platform: Works on both **Linux** and **macOS**
- 🔄 Looping background notifications every 10 minutes as the next prayer approaches
- 🔊 Adjustable voice volume with commands `v +` and `v -`
- 🗣️ Switch between Arabic and English voices using `ar` / `en`
- 🕒 Add alarms and countdown timers (`alarm`, `cdtimer`, `timer`)
- 🔔 Play Azan MP3 with `play azan`

---

## 💬 Voice Engine

### Linux
- Uses `espeak-ng` or `espeak` with adjustable pitch and speed
- Optional WAV sound via `aplay`

### macOS
- Uses native `say` command with voices like "Alex", "Samantha", "Maged"
- Plays bell or azan using `afplay`

---

## 🔧 Installation

### 🐧 Linux

```bash
sudo apt update
sudo apt install espeak-ng jq curl at
```

> Optionally install `alsa-utils` for volume control.

### 🍎 macOS

```bash
brew install jq
```

---

## 🚀 Usage

### Linux

```bash
chmod +x prayer.sh
./prayer.sh
```

### macOS

```bash
chmod +x prayer_mac.sh
./prayer_mac.sh
```

---

## ⌨️ Commands (Inside REPL)

| Command        | Description                                  |
|----------------|----------------------------------------------|
| `now`          | Announce remaining time to next prayer       |
| `ar` / `en`    | Switch language and voice                    |
| `mute on/off`  | Enable or disable voice output               |
| `alarm name hh:mm` | Set an alarm                            |
| `cdtimer name hh:mm` | Start countdown timer                 |
| `timer name start/stop/pause` | Stopwatch actions            |
| `v +` / `v -`  | Increase / decrease volume                   |
| `play azan`    | Play `adhan.mp3` if available                |
| `persist`      | Save current settings                        |
| `exit` / `quit`| Exit the script                              |

---

## 📁 Included Files

- `prayer.sh`: Linux version
- `prayer_mac.sh`: macOS version
- `bell.wav`: Optional bell sound
- `adhan.mp3`: Optional azan MP3
- `README.md`: This guide

---

## 🤲 License

This script is released into the **public domain**.

> Use it freely, share it widely, modify as needed… and don't forget to remember us in your prayers.

---

## 🔗 GitHub Repository

[👉 https://github.com/Amr1977/sh_prayer](https://github.com/Amr1977/sh_prayer)

---

## 🔧 REPL Command Reference

| Command                           | Description                                                     |
|----------------------------------|-----------------------------------------------------------------|
| `now`                            | Announces time remaining until next prayer                      |
| `ar`                             | Switches voice/language to Arabic                               |
| `en`                             | Switches voice/language to English                              |
| `mute on` / `mute off`           | Enables or disables all voice announcements                     |
| `alarm <name> <hh:mm>`           | Sets a named alarm at specified time                            |
| `cdtimer <name> <hh:mm>`         | Starts a countdown timer for given duration                     |
| `timer <name> start`             | Starts a named stopwatch timer                                  |
| `timer <name> stop`              | Stops a named stopwatch and logs elapsed time                   |
| `timer <name> pause`             | Pauses a named stopwatch timer (not yet implemented)            |
| `v +` / `v -`                    | Increases or decreases the system master volume                 |
| `play azan`                      | Plays the Azan MP3 file (adhan.mp3)                             |
| `persist`                        | Saves the current language, mute, and voice settings            |
| `exit` / `quit`                  | Exits the REPL loop and terminates the script                   |

---

