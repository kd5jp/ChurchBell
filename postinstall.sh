#!/usr/bin/env bash
set -e

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_USER="${CHURCHBELL_SERVICE_USER:-churchbells}"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

PASS=0
FAIL=0

pass() {
    echo -e "${GREEN}[PASS]${RESET} $1"
    PASS=$((PASS+1))
}

fail() {
    echo -e "${RED}[FAIL]${RESET} $1"
    FAIL=$((FAIL+1))
}

echo "=== ChurchBell Post‑Install Verification ==="

# ---------------------------------------------------------
# 1. Check systemd services
# ---------------------------------------------------------
SERVICES=("churchbell-home.service" "churchbell.service")

for svc in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "$svc"; then
        pass "$svc installed"
    else
        fail "$svc missing"
    fi

    if systemctl is-enabled "$svc" &>/dev/null; then
        pass "$svc enabled"
    else
        fail "$svc not enabled"
    fi

    if systemctl is-active "$svc" &>/dev/null; then
        pass "$svc running"
    else
        fail "$svc not running"
    fi
done

# ---------------------------------------------------------
# 2. Check ports
# ---------------------------------------------------------
if sudo lsof -i :80 &>/dev/null; then
    pass "Port 80 (home page) is listening"
else
    fail "Port 80 is NOT listening"
fi

if sudo lsof -i :8080 &>/dev/null; then
    pass "Port 8080 (scheduler) is listening"
else
    fail "Port 8080 is NOT listening"
fi

# ---------------------------------------------------------
# 3. Check filesystem
# ---------------------------------------------------------
[ -d "$APP_DIR/venv" ] && pass "Virtual environment exists" || fail "Missing venv"
[ -f "$APP_DIR/bells.db" ] && pass "Database exists" || fail "Missing bells.db"
[ -d "$APP_DIR/sounds" ] && pass "Sounds directory exists" || fail "Missing sounds directory"

# ---------------------------------------------------------
# 4. Check ownership
# ---------------------------------------------------------
OWNER=$(stat -c "%U" "$APP_DIR")
if [[ "$OWNER" == "$SERVICE_USER" ]]; then
    pass "App directory owned by $SERVICE_USER"
else
    fail "App directory owned by $OWNER (expected $SERVICE_USER)"
fi

# ---------------------------------------------------------
# 5. Audio test
# ---------------------------------------------------------
if command -v aplay &>/dev/null; then
    pass "aplay installed"
else
    fail "aplay missing"
fi

# ---------------------------------------------------------
# Summary
# ---------------------------------------------------------
echo
echo "=== Verification Summary ==="
echo -e "${GREEN}Passed: $PASS${RESET}"
echo -e "${RED}Failed: $FAIL${RESET}"

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}System is NOT fully operational. Review failures above.${RESET}"
    exit 1
else
    echo -e "${GREEN}System is fully operational!${RESET}"
fi
