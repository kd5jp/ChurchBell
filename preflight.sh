#!/usr/bin/env bash
set -e

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo -e "${GREEN}[PASS]${RESET} $1"
    PASS_COUNT=$((PASS_COUNT+1))
}

fail() {
    echo -e "${RED}[FAIL]${RESET} $1"
    FAIL_COUNT=$((FAIL_COUNT+1))
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

echo "=== ChurchBell Preflight Check ==="
echo "Checking system readiness..."

# ---------------------------------------------------------
# 1. Check OS
# ---------------------------------------------------------
if grep -qi "raspbian\|debian" /etc/os-release; then
    pass "OS is Debian/Raspberry Pi based"
else
    warn "OS is not Debian-based. Script may still work, but not guaranteed."
fi

# ---------------------------------------------------------
# 2. Check pi user
# ---------------------------------------------------------
if id pi &>/dev/null; then
    pass "User 'pi' exists"
else
    fail "User 'pi' does NOT exist. Create it before installing."
fi

# ---------------------------------------------------------
# 3. Check pi group memberships
# ---------------------------------------------------------
REQUIRED_GROUPS=(audio video gpio input spi i2c dialout)

for grp in "${REQUIRED_GROUPS[@]}"; do
    if id -nG pi | grep -qw "$grp"; then
        pass "pi is in group: $grp"
    else
        fail "pi is NOT in group: $grp"
    fi
done

# ---------------------------------------------------------
# 4. Check Python version
# ---------------------------------------------------------
PY_VER=$(python3 -V 2>/dev/null || true)
if [[ "$PY_VER" =~ 3\.[8-9]|3\.1[0-9] ]]; then
    pass "Python version OK ($PY_VER)"
else
    fail "Python 3.8+ required. Found: $PY_VER"
fi

# ---------------------------------------------------------
# 5. Check required packages
# ---------------------------------------------------------
REQUIRED_PKGS=(python3 python3-venv python3-pip sox alsa-utils git)

for pkg in "${REQUIRED_PKGS[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        pass "Package installed: $pkg"
    else
        fail "Missing package: $pkg"
    fi
done

# ---------------------------------------------------------
# 6. Check directory ownership
# ---------------------------------------------------------
OWNER=$(stat -c "%U" "$APP_DIR")
if [[ "$OWNER" == "pi" ]]; then
    pass "App directory owned by pi"
else
    warn "App directory owned by $OWNER (expected pi)"
fi

# ---------------------------------------------------------
# 7. Check port availability
# ---------------------------------------------------------
if ! sudo lsof -i :80 &>/dev/null; then
    pass "Port 80 is free"
else
    fail "Port 80 is in use"
fi

if ! sudo lsof -i :8080 &>/dev/null; then
    pass "Port 8080 is free"
else
    fail "Port 8080 is in use"
fi

# ---------------------------------------------------------
# 8. Check audio output
# ---------------------------------------------------------
if command -v speaker-test &>/dev/null; then
    pass "Audio tools installed"
else
    fail "Audio tools missing (alsa-utils)"
fi

# ---------------------------------------------------------
# 9. Check systemd availability
# ---------------------------------------------------------
if pidof systemd &>/dev/null; then
    pass "systemd is running"
else
    fail "systemd not detected — services will not install"
fi

# ---------------------------------------------------------
# Summary
# ---------------------------------------------------------
echo
echo "=== Preflight Summary ==="
echo -e "${GREEN}Passed: $PASS_COUNT${RESET}"
echo -e "${RED}Failed: $FAIL_COUNT${RESET}"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "${RED}System is NOT ready for install. Fix the failures above.${RESET}"
    exit 1
else
    echo -e "${GREEN}System is ready for install! Run ./install.sh next.${RESET}"
fi
