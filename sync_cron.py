#!/usr/bin/env python3
import sqlite3
from pathlib import Path
import subprocess

APP_DIR = Path(__file__).resolve().parent
DB_PATH = APP_DIR / "bells.db"
PLAY_SCRIPT = APP_DIR / "play_alarm.sh"

def get_alarms():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("""
        SELECT id, day_of_week, time_str, sound_path, enabled
        FROM alarms
        WHERE enabled = 1
    """)
    rows = cur.fetchall()
    conn.close()
    return rows

def build_cron_lines(alarms):
    lines = []
    for row in alarms:
        alarm_id = row["id"]
        dow = row["day_of_week"]  # 0=Mon .. 6=Sun
        time_str = row["time_str"]  # "HH:MM"
        sound_path = row["sound_path"]

        hour, minute = time_str.split(":")
        # cron: minute hour * * day_of_week(1-7, Mon=1)
        cron_dow = (dow + 1)  # 0->1, 6->7

        line = f"# ChurchBell Alarm ID {alarm_id}\n"
        line += f"{int(minute)} {int(hour)} * * {cron_dow} {PLAY_SCRIPT} {sound_path}\n"
        lines.append(line)
    return lines

def get_existing_crontab():
    try:
        result = subprocess.run(
            ["crontab", "-l"],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return ""
        return result.stdout
    except Exception:
        return ""

def filter_out_churchbell(crontab_text):
    lines = crontab_text.splitlines()
    filtered = []
    skip_next = False
    for line in lines:
        if line.strip().startswith("# ChurchBell Alarm ID"):
            skip_next = True
            continue
        if skip_next:
            skip_next = False
            continue
        filtered.append(line)
    return "\n".join(filtered).strip() + "\n"

def write_crontab(new_text):
    proc = subprocess.Popen(["crontab", "-"], stdin=subprocess.PIPE, text=True)
    proc.communicate(new_text)

def main():
    alarms = get_alarms()
    cron = get_existing_crontab()
    cron = filter_out_churchbell(cron)
    alarm_lines = build_cron_lines(alarms)
    new_cron = cron + ("\n".join(alarm_lines) + "\n" if alarm_lines else "")
    write_crontab(new_cron)

if __name__ == "__main__":
    main()
