# Raspberry Pi Installation Troubleshooting Guide

## Common Installation Errors and Solutions

### 1. PipeWire Installation Error

**Error:** `E: Unable to locate package pipewire` or similar

**Solution:**
```bash
# Update package lists
sudo apt update

# Install PipeWire (may need to enable repositories)
sudo apt install -y pipewire pipewire-alsa pipewire-pulse wireplumber

# If pipewire is not available, check your Pi OS version
cat /etc/os-release

# For older Pi OS versions, you may need to add repositories or use ALSA fallback
```

**Alternative for older Pi OS:**
If PipeWire is not available, you can temporarily use ALSA but note it's not supported for Pi3:
```bash
sudo apt install -y alsa-utils
# Then manually edit play_alarm.sh and app.py to use aplay temporarily
```

---

### 2. Service User Permission Errors

**Error:** `Permission denied` when accessing files or directories

**Solution:**
```bash
# Check service user exists
id churchbells

# Fix ownership
sudo chown -R churchbells:churchbells /home/pi/ChurchBell
sudo chmod -R 755 /home/pi/ChurchBell

# Ensure service user is in audio group
sudo usermod -aG audio churchbells
```

---

### 3. Port Already in Use

**Error:** `Address already in use` or service fails to start

**Solution:**
```bash
# Check what's using port 8080
sudo lsof -i :8080

# Check what's using port 80
sudo lsof -i :80

# Stop conflicting services
sudo systemctl stop <service-name>

# Or change ports in app.py/home.py if needed
```

---

### 4. Python Virtual Environment Issues

**Error:** `venv/bin/python: No such file or directory`

**Solution:**
```bash
cd /home/pi/ChurchBell

# Remove old venv and recreate
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install flask

# Fix ownership
sudo chown -R churchbells:churchbells venv
```

---

### 5. Database Permission Errors

**Error:** `unable to open database file` or permission errors

**Solution:**
```bash
# Fix database permissions
sudo chown churchbells:churchbells /home/pi/ChurchBell/bells.db
sudo chmod 664 /home/pi/ChurchBell/bells.db

# If database doesn't exist, it will be created on first run
```

---

### 6. Cron Not Running Alarms

**Error:** Alarms not firing at scheduled times

**Solution:**
```bash
# Check cron service
sudo systemctl status cron

# Check cron jobs for service user
sudo crontab -u churchbells -l

# Regenerate cron jobs
cd /home/pi/ChurchBell
python3 sync_cron.py

# Check cron logs
sudo tail -f /var/log/syslog | grep CRON
```

---

### 7. Audio Playback Not Working

**Error:** No sound when testing alarms

**Solution:**
```bash
# Test PipeWire directly
pw-play /home/pi/ChurchBell/sounds/chime.wav

# Check PipeWire service
systemctl --user status pipewire
# or
systemctl status pipewire

# Start PipeWire if not running
systemctl --user start pipewire
# or
sudo systemctl start pipewire

# Check audio device
pw-cli list-objects | grep -i audio

# Test with aplay (if available) to verify hardware
aplay /home/pi/ChurchBell/sounds/chime.wav
```

---

### 8. Systemd Service Failures

**Error:** Service fails to start or keeps restarting

**Solution:**
```bash
# Check service status
sudo systemctl status churchbell.service
sudo systemctl status churchbell-home.service

# Check logs
sudo journalctl -u churchbell.service -n 50 --no-pager
sudo journalctl -u churchbell-home.service -n 50 --no-pager

# Common issues:
# - Wrong path in ExecStart
# - Missing dependencies
# - Permission issues
# - Port conflicts
```

---

### 9. Git Permission Errors

**Error:** Cannot pull updates due to permission errors

**Solution:**
```bash
# Fix .git ownership (should be owned by pi user, not churchbells)
sudo chown -R pi:pi /home/pi/ChurchBell/.git

# Ensure pi user can write
sudo chmod -R 755 /home/pi/ChurchBell/.git
```

---

### 10. Missing Dependencies

**Error:** `ModuleNotFoundError` or missing Python packages

**Solution:**
```bash
cd /home/pi/ChurchBell
source venv/bin/activate
pip install -r requirements.txt

# If requirements.txt doesn't exist, install manually
pip install flask
```

---

## Step-by-Step Clean Installation

If you're having persistent issues, try a clean install:

```bash
# 1. Stop services
sudo systemctl stop churchbell.service
sudo systemctl stop churchbell-home.service

# 2. Backup your database (if you have alarms configured)
cp /home/pi/ChurchBell/bells.db /home/pi/ChurchBell/bells.db.backup

# 3. Remove old installation
sudo systemctl disable churchbell.service
sudo systemctl disable churchbell-home.service
sudo rm /etc/systemd/system/churchbell.service
sudo rm /etc/systemd/system/churchbell-home.service
sudo systemctl daemon-reload

# 4. Clean up (optional - keeps your data)
cd /home/pi/ChurchBell
rm -rf venv

# 5. Run preflight check
./preflight.sh

# 6. Run installation
./install.sh

# 7. Verify installation
./postinstall.sh
```

---

## Verification Commands

After installation, verify everything works:

```bash
# Check services
sudo systemctl status churchbell.service --no-pager
sudo systemctl status churchbell-home.service --no-pager

# Check ports
sudo lsof -i :80
sudo lsof -i :8080

# Test audio
pw-play /home/pi/ChurchBell/sounds/chime.wav

# Check database
sqlite3 /home/pi/ChurchBell/bells.db "SELECT * FROM alarms;"

# Check cron
sudo crontab -u churchbells -l
```

---

## Getting Help

If you encounter an error not listed here:

1. **Check the logs:**
   ```bash
   sudo journalctl -u churchbell.service -n 100
   ```

2. **Run diagnostics:**
   ```bash
   ./diagnostics.sh
   ```

3. **Check service user permissions:**
   ```bash
   sudo -u churchbells whoami
   sudo -u churchbells ls -la /home/pi/ChurchBell
   ```

4. **Test manually:**
   ```bash
   sudo -u churchbells /home/pi/ChurchBell/venv/bin/python /home/pi/ChurchBell/app.py
   ```

---

## Pi3-Specific Notes

- **PipeWire is required** for Pi3 compatibility
- If PipeWire is not available, the system will fail
- Check your Pi OS version: `cat /etc/os-release`
- Newer Pi OS versions include PipeWire by default
- Older versions may need manual PipeWire installation

---

**Last Updated:** January 31, 2026
