# Fix PipeWire "Host is down" Error

## Problem
`pw-play` works from CLI but fails from Flask with: `error: pw_context_connect() failed: Host is down`

## Root Cause
PipeWire runs as a **user service**, and systemd services don't automatically have access to the user's PipeWire session socket.

## Solution Applied

### 1. Systemd Service File (`install.sh`)
Added `XDG_RUNTIME_DIR` environment variable:
```ini
Environment="XDG_RUNTIME_DIR=/run/user/${SERVICE_UID}"
```

### 2. Python Code (`app.py`)
Set up environment in `play_sound()`:
```python
env = os.environ.copy()
env["XDG_RUNTIME_DIR"] = f"/run/user/{os.getuid()}"
env["HOME"] = user_home
env["USER"] = current_user
```

### 3. Ensure PipeWire User Services Start
Updated install.sh to enable and start PipeWire user services.

## After Installing/Updating

**On your Pi, run:**

```bash
# 1. Restart the service to pick up new environment
sudo systemctl daemon-reload
sudo systemctl restart churchbell.service

# 2. Ensure PipeWire user service is running
systemctl --user status pipewire
systemctl --user start pipewire
systemctl --user start pipewire-pulse

# 3. Verify XDG_RUNTIME_DIR exists
echo $XDG_RUNTIME_DIR
# Should show: /run/user/1000 (or your user ID)

# 4. Test from service context
sudo -u pi systemd-run --user --setenv=XDG_RUNTIME_DIR=/run/user/1000 pw-play /home/pi/ChurchBell/sounds/chime.wav
```

## If Still Not Working

The user may need to log in once to create the PipeWire session. Alternatively, you can:

1. **Enable lingering** (allows user services without login):
   ```bash
   sudo loginctl enable-linger pi
   ```

2. **Check PipeWire is running**:
   ```bash
   systemctl --user status pipewire
   pw-cli info
   ```

3. **Test manually**:
   ```bash
   sudo -u pi XDG_RUNTIME_DIR=/run/user/1000 pw-play /home/pi/ChurchBell/sounds/chime.wav
   ```
