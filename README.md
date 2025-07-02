# 🕌 Prayer Time Notifier (Bash Script for Linux)

A lightweight Bash script that **announces upcoming Muslim prayer times** using text-to-speech (TTS) and desktop notifications. It auto-detects your location, fetches accurate prayer times, and provides a powerful interactive REPL for control and customization.

> 💡 Ideal for terminal dashboards, automation via `cron`, or running in the background on your Linux system.

---

## 🌟 Features

- 📍 **Auto-location:** Detects your city/country via [IPInfo](https://ipinfo.io/)
- 🕌 **Accurate Times:** Fetches prayer times from [MuslimSalat](https://muslimsalat.com/)
- 🕐 **Voice Announcements:** Announces remaining time to next prayer using TTS
- 🔔 **Azan Playback:** Plays Azan MP3 with `play azan`
- 🔄 **Smart Intervals:** Customizable and intelligent announcement intervals as prayer approaches
- ⏳ **Final Countdown:** Announces every few seconds in the last minute
- 🔊 **Volume Control:** Adjust system volume with `v +` and `v -`
- 🗣️ **Language Switch:** Instantly switch between Arabic and English voices
- 📝 **Settings Persistence:** All preferences saved and loaded automatically
- 🛡️ **Robust Locking:** Prevents multiple instances and cleans up stale locks
- 🖥️ **Desktop Notifications:** Uses `notify-send` (can be disabled)
- 🕒 **Show Prayer Times:** View today’s prayer schedule and last third of the night
- 🧩 **Custom Intervals:** Announce at custom intervals when remaining time is below a threshold

---

## 🛠️ Requirements

- `bash`
- `espeak` or `espeak-ng`
- `jq`
- `curl`
- `notify-send` (for notifications)
- `amixer` (for volume control)
- `mpv` (for Azan playback, optional)

Install on Ubuntu/Debian:
```bash
sudo apt update
sudo apt install espeak-ng jq curl at alsa-utils mpv
```

---

## 🚀 Quick Start

```bash
chmod +x prayer.sh
./prayer.sh
```

---

## ⌨️ Interactive REPL Commands

| Command                        | Description                                                        |
|---------------------------------|--------------------------------------------------------------------|
| `now`                          | Announce remaining time to next prayer                             |
| `ar` / `en`                    | Switch language and voice                                          |
| `mute on` / `mute off`         | Enable or disable voice announcements                              |
| `play azan`                    | Play Azan MP3 if available                                         |
| `v +` / `v -`                  | Increase / decrease system volume                                  |
| `set interval N`               | Set minutes interval for regular announcements                     |
| `set announce minutes N`       | Set threshold for frequent announcements (in minutes)              |
| `set announce seconds N`       | Set threshold for countdown (in seconds)                           |
| `on HH:MM PERIOD`              | Announce every PERIOD minutes when remaining time ≤ HH:MM          |
| `show settings`                | Display current settings                                           |
| `times`                        | Show today's prayer times and last third of the night              |
| `out`                          | Record OUT entry for current prayer                                |
| `reload`                       | Reload settings from disk                                          |
| `persist`                      | Save current settings                                              |
| `help`                         | Show help message                                                  |
| `exit` / `quit`                | Exit the script      
---

## 🔒 Robust Locking

- Prevents multiple instances using a PID lock file.
- Automatically removes stale lock files if the previous process is gone.

---

## 📝 Settings

Settings are saved in `~/.prayer_settings.conf` and loaded automatically on startup.

---

## 📁 Included Files

- `prayer.sh` — Main script for Linux
- `bell.wav` — Optional bell sound
- `azan.mp3` — Optional Azan MP3
- `README.md` — This guide

---

## 🤲 License

Released into the **public domain**.

> Use freely, share widely, and remember us in your prayers.

---

## 🔗 GitHub

[https://github.com/Amr1977/sh_prayer](https://github.com/Amr1977/sh_prayer)