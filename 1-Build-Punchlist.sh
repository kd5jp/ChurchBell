#!/usr/bin/env bash
# Local punchlist (untracked). Edit freely.
# Use [OK] / [BROKEN] / [TODO] tags for quick scans.

BASELINE_BRANCH="v2.0-reset"
BASELINE_COMMIT="d68b978"
LAST_UPDATED="$(date +%Y-%m-%d)"

cat <<EOF
=== ChurchBell Build Punchlist ===
Baseline: ${BASELINE_BRANCH} (${BASELINE_COMMIT})
Last updated: ${LAST_UPDATED}

Status
- Login: [OK] leave as-is
- Cron: [OK] working
- Audio test button: [TODO]
- Backups: [TODO]
- Restore: [TODO]
- Update workflow: [TODO]
- HTTPS redirect: [TODO]
- UI polish: [TODO]

Working
- [OK] Login/auth
- [OK] Alarm schedule (cron)

Broken
- [BROKEN] (fill in)

Next focus
- (fill in one area only)

Notes
- (add notes as you go)
EOF
