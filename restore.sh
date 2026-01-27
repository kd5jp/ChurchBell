#!/bin/bash
set -euo pipefail

INSTALL_DIR="${CHURCHBELL_APP_DIR:-/opt/church-bells}"
BACKUP_DIR="${INSTALL_DIR}/backups"
LOG_DIR="/var/log/churchbell"
LOGFILE="${LOG_DIR}/restore.log"

BACKUP_FILE="${1:-${BACKUP_DIR}/churchbells-backup-latest.zip}"

sudo mkdir -p "$LOG_DIR"
echo "=== Restore started at $(date) ===" | tee -a "$LOGFILE"

# Stop service
systemctl stop churchbell.service || true

# Validate backup file
if [ ! -f "$BACKUP_FILE" ]; then
  echo "[ERROR] Backup file not found: $BACKUP_FILE" | tee -a "$LOGFILE"
  exit 1
fi

echo "[INFO] Using backup file: $BACKUP_FILE" | tee -a "$LOGFILE"

# Extract backup
unzip -o "$BACKUP_FILE" -d "$INSTALL_DIR" | tee -a "$LOGFILE"

# Restore alarms into DB
if [ -f "${INSTALL_DIR}/alarms.json" ]; then
  echo "[INFO] Importing alarms into database..." | tee -a "$LOGFILE"
sqlite3 "${INSTALL_DIR}/bells.db" <<EOF
.mode json
.import ${INSTALL_DIR}/alarms.json alarms
EOF
else
  echo "[WARN] No alarms.json found in backup" | tee -a "$LOGFILE"
fi

# Restart service
systemctl start churchbell.service

echo "=== Restore completed at $(date) ===" | tee -a "$LOGFILE"
