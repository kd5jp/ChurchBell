#!/bin/bash
set -e

APP_DIR="/home/pi/ChurchBell"

echo "=== ChurchBell Preflight Check ==="
echo ""

PASS=true

# ------------------------------------------------------------
# Helper to print PASS/FAIL
# ------------------------------------------------------------
check() {
    local label="$1"
    local cmd="$2"

    echo -n "Checking $label... "

    if eval "$cmd" >/dev/null 2>&1; then
        echo "OK"
    else
        echo "FAIL"
        PASS=false
    fi
}

# ------------------------------------------------------------
# 1. Basic system checks
# ------------------------------------------------------------
check "Python3 installed" "command -v python3"
check "pip installed" "command -v pip3"
check "venv module available" "python3 -m venv --help"
check "git installed" "command -v git"
check "cron installed" "command -v cron"
check "systemd available" "pidof systemd"
check "sqlite3 installed" "command -v sqlite3"

# ------------------------------------------------------------
# 2. Audio checks
# ------------------------------------------------------------
check "ALSA utilities installed" "command -v aplay"
check "Audio device present" "aplay -l"

# ------------------------------------------------------------
# 3. Network checks
# ------------------------------------------------------------
check "Network connectivity" "ping -c1 8.8.8.8"
check "DNS resolution" "ping -c1 google.com"

# ------------------------------------------------------------
# 4. Directory checks
# ------------------------------------------------------------
echo -n "Checking write access to $APP_DIR... "
if mkdir -p "$APP_DIR" 2>/dev/null; then
    echo "OK"
else
    echo "FAIL"
    PASS=false
fi

# ------------------------------------------------------------
# 5. System time sanity
# ------------------------------------------------------------
echo -n "Checking system clock... "
if date >/dev/null 2>&1; then
    echo "OK"
else
    echo "FAIL"
    PASS=false
fi

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------
echo ""
echo "=== Preflight Summary ==="

if [ "$PASS" = true ]; then
    echo "All checks PASSED. System is ready for install."
    exit 0
else
    echo "One or more checks FAILED. Please fix issues before running install.sh."
    exit 1
fi
