#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/churchbell/diagnostics.log"
echo "=== Diagnostics run at $(date) ===" | tee -a "$LOGFILE"

# System info
echo "[INFO] System info:" | tee -a "$LOGFILE"
uname -a | tee -a "$LOGFILE"
python3 --version | tee -a "$LOGFILE"
df -h | tee -a "$LOGFILE"
free -h | tee -a "$LOGFILE"

# Service status
echo "[INFO] Checking systemd services..." | tee -a "$LOGFILE"
systemctl status churchbell.service --no-pager | tee -a "$LOGFILE"

# Ports
echo "[INFO] Checking listening ports..." | tee -a "$LOGFILE"
ss -tuln | grep -E ':80|:443|:8080' | tee -a "$LOGFILE" || echo "No expected ports found" | tee -a "$LOGFILE"

# Database check
echo "[INFO] Checking database schema..." | tee -a "$LOGFILE"
sqlite3 /var/lib/churchbell/churchbell.db ".tables" | tee -a "$LOGFILE"

# Filesystem check
for dir in /var/lib/churchbell/sounds /var/lib/churchbell/backups /var/lib/churchbell/schedules; do
  if [ -d "$dir" ]; then
    echo "[OK] $dir exists" | tee -a "$LOGFILE"
    [ -w "$dir" ] && echo "[OK] $dir writable" | tee -a "$LOGFILE" || echo "[WARN] $dir not writable" | tee -a "$LOGFILE"
  else
    echo "[ERROR] $dir missing" | tee -a "$LOGFILE"
  fi
done

# Config validation
echo "[INFO] Comparing configs..." | tee -a "$LOGFILE"
diff -rq /etc/churchbell/ /opt/churchbell/defaults/ | tee -a "$LOGFILE" || true

# Logs
echo "[INFO] Last 50 lines of service logs:" | tee -a "$LOGFILE"
journalctl -u churchbell.service -n 50 --no-pager | tee -a "$LOGFILE"

echo "=== Diagnostics completed at $(date) ===" | tee -a "$LOGFILE"
