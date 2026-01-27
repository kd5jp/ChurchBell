#!/bin/bash
set -euo pipefail

INSTALL_DIR="/opt/church-bells"
BACKUP_DIR="${INSTALL_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/churchbells-backup-${TIMESTAMP}.zip"
LATEST_FILE="${BACKUP_DIR}/churchbells-backup-latest.zip"

# Ensure directories exist with correct ownership
if [ ! -d "$INSTALL_DIR" ]; then
  sudo mkdir -p "$INSTALL_DIR"
  sudo chown churchbells:churchbells "$INSTALL_DIR"
fi

sudo mkdir -p "$BACKUP_DIR"
sudo chown churchbells:churchbells "$BACKUP_DIR"

# Run backup as service user
sudo -u churchbells bash <<EOF
sqlite3 ${INSTALL_DIR}/churchbells.db <<SQL
.output ${INSTALL_DIR}/alarms.json
.mode json
SELECT * FROM alarms;
SQL

zip -r "$BACKUP_FILE" "${INSTALL_DIR}/alarms.json" "${INSTALL_DIR}/sounds"
ln -sf "$BACKUP_FILE" "$LATEST_FILE"
EOF

echo "Backup created: $BACKUP_FILE"
