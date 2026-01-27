import os
import sqlite3
import threading
import time
import datetime
import subprocess
from pathlib import Path
from flask import Flask, render_template, request, redirect, url_for, session, flash, g

APP_DIR = Path(__file__).resolve().parent
DB_PATH = APP_DIR / "bells.db"
SOUNDS_DIR = APP_DIR / "sounds"

DEFAULT_USERNAME = "admin"
DEFAULT_PASSWORD = "changeme"  # stored as plain text for now, appliance-style

app = Flask(__name__)
app.secret_key = "change-this-secret-key"  # replace in production
app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
app.config["SESSION_COOKIE_SECURE"] = False  # set True if using HTTPS

# ---------- DB helpers ----------

def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(
            DB_PATH,
            timeout=5,
            check_same_thread=False
        )
        g.db.row_factory = sqlite3.Row
    return g.db

@app.teardown_appcontext
def close_db(exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()

def init_db():
    conn = sqlite3.connect(DB_PATH, timeout=5, check_same_thread=False)
    conn.row_factory = sqlite3.Row   # <-- REQUIRED FIX
    cur = conn.cursor()

    # users table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL
        )
    """)

    # alarms table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS alarms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            day_of_week INTEGER NOT NULL,
            time_str TEXT NOT NULL,
            sound_path TEXT NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 1,
            last_run_date TEXT
        )
    """)

    # settings table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            volume INTEGER NOT NULL DEFAULT 70
        )
    """)

    # default admin user
    cur.execute("SELECT COUNT(*) AS c FROM users")
    if cur.fetchone()["c"] == 0:
        cur.execute(
            "INSERT INTO users (username, password) VALUES (?, ?)",
            (DEFAULT_USERNAME, DEFAULT_PASSWORD),
        )

    # default settings row
    cur.execute("SELECT COUNT(*) AS c FROM settings WHERE id = 1")
    if cur.fetchone()["c"] == 0:
        cur.execute("INSERT INTO settings (id, volume) VALUES (1, 70)")

    conn.commit()
    conn.close()

# ---------- auth ----------

def login_required(view):
    from functools import wraps
    @wraps(view)
    def wrapped(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("login"))
        return view(*args, **kwargs)
    return wrapped

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()

        db = get_db()
        cur = db.execute(
            "SELECT id, password FROM users WHERE username = ?",
            (username,),
        )
        row = cur.fetchone()
        if row and row["password"] == password:
            session["user_id"] = row["id"]
            session["username"] = username
            return redirect(url_for("alarms"))
        flash("Invalid username or password", "error")
    return render_template("login.html")

@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))

@app.route("/change_password", methods=["POST"])
@login_required
def change_password():
    current = request.form.get("current_password", "")
    new = request.form.get("new_password", "")
    confirm = request.form.get("confirm_password", "")

    if not new or new != confirm:
        flash("New passwords do not match.", "error")
        return redirect(url_for("alarms"))

    db = get_db()
    cur = db.execute(
        "SELECT password FROM users WHERE id = ?",
        (session["user_id"],),
    )
    row = cur.fetchone()
    if not row or row["password"] != current:
        flash("Current password is incorrect.", "error")
        return redirect(url_for("alarms"))

    db.execute(
        "UPDATE users SET password = ? WHERE id = ?",
        (new, session["user_id"]),
    )
    db.commit()
    flash("Password updated.", "success")
    return redirect(url_for("alarms"))

# ---------- alarms ----------

@app.route("/")
@login_required
def alarms():
    db = get_db()
    alarms = db.execute(
        """
        SELECT id, day_of_week, time_str, sound_path, enabled
        FROM alarms
        ORDER BY day_of_week ASC, time_str ASC
        """
    ).fetchall()

    settings = db.execute(
        "SELECT volume FROM settings WHERE id = 1"
    ).fetchone()
    volume = settings["volume"] if settings else 70

    return render_template("alarms.html", alarms=alarms, volume=volume)

@app.route("/add_alarm", methods=["POST"])
@login_required
def add_alarm():
    day = int(request.form.get("day_of_week"))
    time_str = request.form.get("time_str", "").strip()
    sound = request.form.get("sound_path", "sounds/chime.wav").strip()
    enabled = 1 if request.form.get("enabled") == "on" else 0

    db = get_db()
    db.execute(
        "INSERT INTO alarms (day_of_week, time_str, sound_path, enabled) VALUES (?, ?, ?, ?)",
        (day, time_str, sound, enabled),
    )
    db.commit()
    return redirect(url_for("alarms"))

@app.route("/toggle_alarm/<int:alarm_id>")
@login_required
def toggle_alarm(alarm_id):
    db = get_db()
    row = db.execute(
        "SELECT enabled FROM alarms WHERE id = ?",
        (alarm_id,),
    ).fetchone()
    if row:
        new_val = 0 if row["enabled"] else 1
        db.execute(
            "UPDATE alarms SET enabled = ? WHERE id = ?",
            (new_val, alarm_id),
        )
        db.commit()
    return redirect(url_for("alarms"))

@app.route("/delete_alarm/<int:alarm_id>")
@login_required
def delete_alarm(alarm_id):
    db = get_db()
    db.execute("DELETE FROM alarms WHERE id = ?", (alarm_id,))
    db.commit()
    return redirect(url_for("alarms"))

# ---------- volume ----------

@app.route("/set_volume", methods=["POST"])
@login_required
def set_volume():
    try:
        vol = int(request.form.get("volume", "70"))
        vol = max(0, min(100, vol))
    except ValueError:
        vol = 70

    db = get_db()
    db.execute(
        "UPDATE settings SET volume = ? WHERE id = 1",
        (vol,),
    )
    db.commit()

    try:
        subprocess.run(
            ["amixer", "sset", "Master", f"{vol}%"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass

    return ("", 204)

# ---------- playback & scheduler ----------

def get_current_volume():
    conn = sqlite3.connect(DB_PATH, timeout=5, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    row = cur.execute(
        "SELECT volume FROM settings WHERE id = 1"
    ).fetchone()
    conn.close()
    return row["volume"] if row else 70

def play_sound(sound_path):
    full_path = str((APP_DIR / sound_path).resolve())
    if not os.path.exists(full_path):
        return
    try:
        subprocess.run(
            ["aplay", full_path],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass

def scheduler_loop():
    while True:
        try:
            now = datetime.datetime.now()
            dow = now.weekday()
            current_time = now.strftime("%H:%M")
            today_str = now.strftime("%Y-%m-%d")

            conn = sqlite3.connect(DB_PATH, timeout=5, check_same_thread=False)
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            cur.execute(
                """
                SELECT id, sound_path, last_run_date
                FROM alarms
                WHERE enabled = 1
                  AND day_of_week = ?
                  AND time_str = ?
                """,
                (dow, current_time),
            )
            rows = cur.fetchall()

            for row in rows:
                if row["last_run_date"] == today_str:
                    continue
                play_sound(row["sound_path"])
                cur.execute(
                    "UPDATE alarms SET last_run_date = ? WHERE id = ?",
                    (today_str, row["id"]),
                )
                conn.commit()

            conn.close()
        except Exception:
            pass

        time.sleep(30)

def start_scheduler():
    t = threading.Thread(target=scheduler_loop, daemon=True)
    t.start()

# ---------- main ----------

if __name__ == "__main__":
    if not SOUNDS_DIR.exists():
        SOUNDS_DIR.mkdir(parents=True, exist_ok=True)
    init_db()
    start_scheduler()
    app.run(host="0.0.0.0", port=8080, debug=False, threaded=True)
