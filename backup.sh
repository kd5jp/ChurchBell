#!/bin/bash
set -euo pipefail

SERVICE_USER="${CHURCHBELL_SERVICE_USER:-churchbells}"
INSTALL_DIR="${CHURCHBELL_APP_DIR:-/opt/church-bells}"
BACKUP_DIR="${INSTALL_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/churchbells-backup-${TIMESTAMP}.zip"
LATEST_FILE="${BACKUP_DIR}/churchbells-backup-latest.zip"
LOGFILE="${BACKUP_DIR}/churchbells-backup-${TIMESTAMP}.log"

# Ensure directories exist with correct ownership
if [ ! -d "$INSTALL_DIR" ]; then
  sudo mkdir -p "$INSTALL_DIR"
  sudo chown "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_DIR"
fi

sudo mkdir -p "$BACKUP_DIR"
sudo chown "$SERVICE_USER":"$SERVICE_USER" "$BACKUP_DIR"

# Run backup as service user
sudo -u "$SERVICE_USER" INSTALL_DIR="$INSTALL_DIR" BACKUP_DIR="$BACKUP_DIR" bash <<'EOF'
set -euo pipefail

BACKUP_DIR="\${BACKUP_DIR:-\${INSTALL_DIR}/backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="\${BACKUP_DIR}/churchbells-backup-\${TIMESTAMP}.zip"
LATEST_FILE="\${BACKUP_DIR}/churchbells-backup-latest.zip"
LOGFILE="\${BACKUP_DIR}/churchbells-backup-\${TIMESTAMP}.log"

exec > >(tee -a "\$LOGFILE") 2>&1
echo "[INFO] Starting backup at \$(date)"

sqlite3 "\${INSTALL_DIR}/bells.db" <<SQL
.output \${INSTALL_DIR}/alarms.json
.mode json
SELECT * FROM alarms;
SQL

echo "[INFO] Creating archive \$BACKUP_FILE"
zip -r -q "\$BACKUP_FILE" "\${INSTALL_DIR}/alarms.json" "\${INSTALL_DIR}/sounds"

rm -f "\${INSTALL_DIR}/alarms.json"
ln -sf "\$BACKUP_FILE" "\$LATEST_FILE"

chown "\$USER":"\$USER" "\$BACKUP_FILE" "\$LATEST_FILE"

echo "[INFO] Backup complete: \$BACKUP_FILE"
echo "[INFO] Log saved to \$LOGFILE"
EOF
