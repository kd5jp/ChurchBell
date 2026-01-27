#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/churchbell/factory_reset.log"
PURGE=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --purge) PURGE=true ;;
    *) echo "Unknown option: $arg" ;;
  esac
done

echo "=== Factory reset started at $(date) ===" | tee -a "$LOGFILE"

# Stop services
systemctl stop churchbell.service || true

# Reset configs
echo "[INFO] Restoring default configs..." | tee -a "$LOGFILE"
cp -r /opt/churchbell/defaults/* /etc/churchbell/

# Clear runtime state
echo "[INFO] Clearing runtime state..." | tee -a "$LOGFILE"
rm -rf /var/tmp/churchbell/* /var/cache/churchbell/*

# Purge mode
if [ "$PURGE" = true ]; then
  echo "[INFO] Purging user data..." | tee -a "$LOGFILE"
  rm -rf /var/lib/churchbell/sounds/*
  rm -rf /var/lib/churchbell/backups/*
  rm -rf /var/lib/churchbell/schedules/*
else
  echo "[INFO] Preserving user data (sounds, backups, schedules)" | tee -a "$LOGFILE"
fi

# Reinitialize system
echo "[INFO] Running postinstall..." | tee -a "$LOGFILE"
/opt/churchbell/install.sh --postinstall >> "$LOGFILE" 2>&1

# Restart service
systemctl start churchbell.service

echo "=== Factory reset completed at $(date) ===" | tee -a "$LOGFILE"
factory_reset.log
