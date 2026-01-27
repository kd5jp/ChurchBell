Below is a complete first cut: single Flask app, login, alarms, password change, simple scheduler, volume slider, and install/update/uninstall scripts.

ChurchBellsSystem/
├─ app.py
├─ bells.db              # auto-created
├─ sounds/
│  └─ chime.wav          # created by install.sh
├─ templates/
│  ├─ base.html
│  ├─ login.html
│  └─ alarms.html
├─ static/
│  └─ main.css
├─ install.sh
├─ update.sh
└─ uninstall.sh

# ChurchBellsSystem  
A lightweight, appliance‑grade Raspberry Pi bell scheduler with a simple web interface, persistent volume control, and a modular architecture designed for future expansion.

This project provides a reliable, easy‑to‑use system for scheduling and playing bell chimes on a Raspberry Pi. It includes a default homepage on port 80 and a full bell scheduler UI on port 8080.

---

## Features

### 🔔 Bell Scheduler (Port 8080)
- Login system (default: **admin / changeme**)
- Add, edit, enable/disable, and delete alarms
- Alarms sorted by day of week and time
- Plays WAV files using `aplay`
- Persistent system volume slider pinned to the bottom-left of the UI
- Built‑in default chime sound generated during installation
- Automatic scheduler loop that fires alarms at the correct time

### 🏠 Home Page (Port 80)
- Simple “Work in Progress” landing page
- Links to the Bell Scheduler
- Runs independently from the scheduler service

### 🛠️ System Architecture
- Runs under the **pi** user for predictable audio/device permissions
- Two systemd services:
  - `churchbells-home.service` (port 80)
  - `churchbells.service` (port 8080)
- Designed for future modular services (announcements, livestream, admin tools, etc.)

---

## Requirements

- Raspberry Pi (any model with audio output)
- Raspberry Pi OS or Debian-based Linux
- Python 3.9+
- Audio output configured (HDMI or 3.5mm)
- Internet connection for first install

---

## Installation

Clone the repository:

  git clone https://github.com/kd5jp/ChurchBellsSystem.git
  cd ChurchBellsSystem
- Install dependencies
