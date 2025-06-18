
# 🕌 Prayer Timer Bash Script

A smart Bash script to notify you before the next prayer time using real-time location and voice announcements.

## 🌍 Features

- Auto-detects your location using IP geolocation
- Fetches prayer times using [MuslimSalat API](https://muslimsalat.com/)
- Adjusts for Daylight Saving Time (DST)
- Announces remaining time using voice and countdown in the last minute
- Works on Linux and macOS (compatible versions included)
- Optional bell sound support

## 🎙️ Voice Configuration

- On Linux: Uses `espeak-ng` with custom pitch and speed
- On macOS: Uses `say` with built-in voices like "Alex", "Fred", or "Samantha"

## 🔧 Requirements

### Linux

```bash
sudo apt install espeak-ng jq curl
```

### macOS

```bash
brew install jq
```

## 🔔 Optional: Add bell.wav for sound notification

Place a `bell.wav` file in the same directory if you'd like a sound before each voice announcement.

## 🚀 Usage

```bash
chmod +x prayer.sh
./prayer.sh
```

## 📁 Included Files

- `prayer.sh`: Main script for Linux (espeak)
- `prayer_mac.sh`: Version adapted for macOS (say)
- `README.md`

## 📦 License

Public Domain. Free to use, share, or modify. Pray for us 🤲.
