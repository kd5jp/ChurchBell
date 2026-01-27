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
