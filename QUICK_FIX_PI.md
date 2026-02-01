# Quick Fix Guide for Pi Installation Errors

## 🔍 First: Identify the Error

Run this to see what failed:
```bash
./diagnostics.sh
```

Or check the install log:
```bash
# If you just ran install.sh, check the output
# Look for lines starting with "ERROR" or "FAIL"
```

---

## 🚀 Most Common Fixes

### Fix 1: PipeWire Not Installed

**If you see:** `E: Unable to locate package pipewire`

**Fix:**
```bash
# Update package lists
sudo apt update

# Try installing PipeWire
sudo apt install -y pipewire pipewire-alsa pipewire-pulse wireplumber

# If that fails, check your Pi OS version
cat /etc/os-release

# For very old Pi OS, you may need to upgrade first
sudo apt upgrade -y
```

---

### Fix 2: Service Won't Start

**If you see:** Service fails or keeps restarting

**Fix:**
```bash
# Check what the error is
sudo journalctl -u churchbell.service -n 50 --no-pager

# Common fixes:
# 1. Fix Python venv
cd /home/pi/ChurchBell
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install flask
sudo chown -R churchbells:churchbells venv

# 2. Fix permissions
sudo chown -R churchbells:churchbells /home/pi/ChurchBell
sudo chmod -R 755 /home/pi/ChurchBell

# 3. Restart services
sudo systemctl daemon-reload
sudo systemctl restart churchbell.service
sudo systemctl restart churchbell-home.service
```

---

### Fix 3: Port Already in Use

**If you see:** `Address already in use`

**Fix:**
```bash
# Find what's using the port
sudo lsof -i :8080
sudo lsof -i :80

# Stop it (replace <PID> with the process ID)
sudo kill <PID>

# Or stop the conflicting service
sudo systemctl stop <service-name>

# Then restart ChurchBell services
sudo systemctl restart churchbell.service
sudo systemctl restart churchbell-home.service
```

---

### Fix 4: Permission Denied Errors

**If you see:** `Permission denied` when accessing files

**Fix:**
```bash
# Fix ownership
sudo chown -R churchbells:churchbells /home/pi/ChurchBell

# But keep .git owned by pi user
sudo chown -R pi:pi /home/pi/ChurchBell/.git

# Fix permissions
sudo chmod -R 755 /home/pi/ChurchBell
sudo chmod 664 /home/pi/ChurchBell/bells.db
```

---

### Fix 5: Audio Not Working

**If you see:** No sound when testing

**Fix:**
```bash
# Test PipeWire directly
pw-play /home/pi/ChurchBell/sounds/chime.wav

# If that fails, check PipeWire service
systemctl --user status pipewire
# or
sudo systemctl status pipewire

# Start it if needed
systemctl --user start pipewire
# or
sudo systemctl start pipewire

# Check audio groups
groups churchbells
# Should include 'audio' group
```

---

## 📋 Complete Reinstall (If All Else Fails)

```bash
# 1. Stop everything
sudo systemctl stop churchbell.service churchbell-home.service
sudo systemctl disable churchbell.service churchbell-home.service

# 2. Backup your database (if you have alarms)
cp /home/pi/ChurchBell/bells.db /home/pi/ChurchBell/bells.db.backup

# 3. Remove services
sudo rm /etc/systemd/system/churchbell.service
sudo rm /etc/systemd/system/churchbell-home.service
sudo systemctl daemon-reload

# 4. Clean Python environment
cd /home/pi/ChurchBell
rm -rf venv

# 5. Run preflight check
./preflight.sh

# 6. Install fresh
./install.sh

# 7. Verify
./postinstall.sh
```

---

## ✅ Verify Installation

After fixing, verify everything works:

```bash
# Check services
sudo systemctl status churchbell.service --no-pager
sudo systemctl status churchbell-home.service --no-pager

# Check web access
curl http://localhost:8080
curl http://localhost:80

# Test audio
pw-play /home/pi/ChurchBell/sounds/chime.wav
```

---

## 🆘 Still Having Issues?

1. **Run diagnostics:**
   ```bash
   ./diagnostics.sh
   ```

2. **Check service logs:**
   ```bash
   sudo journalctl -u churchbell.service -n 100
   ```

3. **Check what error you're getting:**
   - Copy the exact error message
   - Check which step of install.sh failed
   - Look at the line number in the error

4. **See full troubleshooting guide:**
   ```bash
   cat PI_INSTALL_TROUBLESHOOTING.md
   ```

---

**Quick Reference:**
- Services: `churchbell.service` (port 8080), `churchbell-home.service` (port 80)
- User: `churchbells`
- Directory: `/home/pi/ChurchBell`
- Database: `/home/pi/ChurchBell/bells.db`
- Audio: `pw-play` (PipeWire) - required for Pi3
