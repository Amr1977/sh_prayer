# 🕌 Prayer Timer Script with Voice Alerts (Linux)

A Bash script to notify you of the next prayer time using your **current location**, with a **deep synthetic voice** and optional **doorbell sound**.

---

## 🔧 Features

- Auto-detects your **city and country**
- Fetches prayer times using [MuslimSalat API](https://muslimsalat.com/)
- Supports **Daylight Saving Time**
- Voice notifications via `espeak-ng` with **deep male MBROLA voice**
- Announces remaining time every:
  - 10 minutes (when > 20 min)
  - 1 minute (when ≤ 20 min)
  - Counts seconds every 2s (when ≤ 1 min)
- Plays optional `bell.wav` if available in script folder

---

## 📦 Requirements

Install the following:

```bash
sudo apt update
sudo apt install espeak-ng mbrola mbrola-us2 jq curl aplay
```

Place a sound file named `bell.wav` in the same folder as the script (optional).

---

## ▶️ Usage

Make the script executable:

```bash
chmod +x prayer.sh
./prayer.sh
```

---

## 🗣️ Voice Customization

- Uses MBROLA deep male voice: `mb-us2`
- Slowed pitch and speed for a Morpheus-like tone:
  ```bash
  VOICE="-v mb-us2"
  PITCH="-p 30"
  SPEED="-s 110"
  ```

Feel free to tweak these for your preferences.

---

## 📁 File Structure

```
your-folder/
├── prayer.sh
└── bell.wav      # Optional: short chime before announcement
```

---

## 📜 License

MIT — share, modify, and enhance freely.

---

## 💬 Credits

- MuslimSalat.com API for prayer times
- MBROLA project for high-quality synthetic voices