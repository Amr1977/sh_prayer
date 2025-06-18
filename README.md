# 🕌 Prayer Time Notifier (Bash Script for macOS & Linux)

A lightweight Bash script that announces the remaining time until the next Islamic prayer (Fajr, Dhuhr, Asr, Maghrib, Isha) based on your location.

Supports both Linux (using `espeak`) and macOS (using `say`), with voice configuration, countdown, and intelligent reminders.

---

## ✨ Features

- 🗺️ Auto-detects your city and country
- 🕰️ Uses [MuslimSalat API](https://muslimsalat.com) to fetch daily prayer times
- ⏱️ Speaks the remaining time to next prayer
- 🔊 Custom voice, pitch, and speed settings
- ⏲️ Announces every 10 minutes when time remaining > 20 minutes
- 🧠 Countdown by seconds in last minute
- 🧭 Automatically adjusts for Daylight Saving Time (DST)

---

## 💻 Supported Platforms

| OS      | Text-to-Speech Engine | Notes                        |
|---------|-----------------------|------------------------------|
| Linux   | `espeak`              | Install via package manager |
| macOS   | `say`                 | Built-in, no installation   |

---

## 🔧 Installation & Usage

### ✅ Linux Setup

```bash
sudo apt install curl jq espeak
git clone https://github.com/Amr1977/sh_prayer
cd sh_prayer
chmod +x prayer.sh
./prayer.sh
```

### 🍏 macOS Setup

```bash
brew install jq
git clone https://github.com/Amr1977/sh_prayer
cd sh_prayer
chmod +x prayer.sh
./prayer.sh
```

---

## 🔊 Custom Voice Settings

### Linux (espeak)

Inside `prayer.sh`:

```bash
VOICE="-v mb-us2"     # Deep male voice
PITCH="-p 30"          # Lower pitch
SPEED="-s 110"         # Slower rate
```

### macOS (say)

Inside `prayer.sh`:

```bash
VOICE="Alex"          # Deepest built-in male voice
SPEED="-r 180"         # Slower rate
```

---

## 📎 Repository

🔗 GitHub: [github.com/Amr1977/sh_prayer](https://github.com/Amr1977/sh_prayer)

---

## 🤲 Contributing

Feel free to fork and improve the script for your local needs. Contributions are welcome—add voice selector UIs, alternative APIs, or multi-language support.

---

## 📜 License

This project is licensed under the MIT License.
