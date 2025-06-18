
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

---

## 💬 Voice Engine

### Linux
- Uses `espeak-ng` with adjustable pitch and speed
- Optional WAV sound via `aplay` (for `bell.wav`)

### macOS
- Uses native `say` command with voices like "Alex", "Samantha", "Fred"
- Plays bell sound using `afplay`

---

## 🔧 Installation

### 🐧 Linux

```bash
sudo apt update
sudo apt install espeak-ng jq curl
```

### 🍎 macOS

```bash
brew install jq
```

> 🔔 Optional: Add `bell.wav` to the script directory to play a chime before voice alerts.

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

The script will:
1. Detect your city and country using IP geolocation
2. Fetch today’s prayer schedule
3. Identify the next upcoming prayer
4. Announce how much time is left at 10-minute intervals
5. Switch to minute-level and second-level countdown as the prayer approaches

---

## 📁 Included Files

- `prayer.sh`: Linux version using `espeak-ng`
- `prayer_mac.sh`: macOS version using `say`
- `bell.wav`: Optional bell sound (not required)
- `README.md`: This guide

---

## 🤲 License

This script is released into the **public domain**.

> Use it freely, share it widely, modify as needed… and don't forget to remember us in your prayers.

---

## 🔗 GitHub Repository

[👉 https://github.com/Amr1977/sh_prayer](https://github.com/Amr1977/sh_prayer)
