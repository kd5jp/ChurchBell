import os
import sqlite3
import subprocess
import pwd
import zipfile
import json
import shutil
from datetime import datetime
from pathlib import Path
from flask import Flask, render_template, request, redirect, url_for, session, flash, g, send_file

APP_DIR = Path(__file__).resolve().parent
DB_PATH = APP_DIR / "bells.db"
SOUNDS_DIR = APP_DIR / "sounds"
BACKUP_DIR = APP_DIR / "backups"

DEFAULT_USERNAME = os.getenv("CHURCHBELL_ADMIN_USER", "admin")
DEFAULT_PASSWORD = os.getenv("CHURCHBELL_ADMIN_PASS", "changeme")  # stored as plain text for now, appliance-style

app = Flask(__name__)
app.secret_key = "change-this-secret-key"  # replace in production
app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
app.config["SESSION_COOKIE_SECURE"] = True  # HTTPS required

# Make helper functions available to templates
@app.context_processor
def inject_permissions():
    return dict(
        is_admin=lambda uid: is_admin(uid) if uid else False,
        has_permission=lambda uid, perm: has_permission(uid, perm) if uid else False,
        get_user_permissions=lambda uid: get_user_permissions(uid) if uid else []
    )


# ---------- CRON SYNC HELPER ----------

def sync_cron():
    """Rebuild system crontab from DB alarms."""
    try:
        subprocess.run(
            [str(APP_DIR / "sync_cron.py")],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


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
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    # users table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'user',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # user_permissions table - stores permissions for non-admin users
    cur.execute("""
        CREATE TABLE IF NOT EXISTS user_permissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            permission TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            UNIQUE(user_id, permission)
        )
    """)
    
    # Available permissions
    # 'bells' - access to bell scheduler/alarms
    # 'backup' - access to backup and restore
    # 'users' - access to user management
    # 'tts' - access to text-to-speech (future)
    # 'announcements' - access to live announcements (future)

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
            "INSERT INTO users (username, password, role) VALUES (?, ?, ?)",
            (DEFAULT_USERNAME, DEFAULT_PASSWORD, "admin"),
        )
    
    # Migrate existing users to have 'user' role if they don't have one
    cur.execute("UPDATE users SET role = 'user' WHERE role IS NULL OR role = ''")

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

def get_user_role(user_id):
    """Get the role of a user"""
    db = get_db()
    user = db.execute("SELECT role FROM users WHERE id = ?", (user_id,)).fetchone()
    return user["role"] if user else None

def is_admin(user_id):
    """Check if user is an admin"""
    return get_user_role(user_id) == "admin"

def has_permission(user_id, permission):
    """Check if user has a specific permission. Admins have all permissions."""
    if is_admin(user_id):
        return True
    
    db = get_db()
    perm = db.execute(
        "SELECT 1 FROM user_permissions WHERE user_id = ? AND permission = ?",
        (user_id, permission)
    ).fetchone()
    return perm is not None

def get_user_permissions(user_id):
    """Get all permissions for a user. Returns list of permission strings."""
    if is_admin(user_id):
        # Admins have all permissions
        return ["bells", "backup", "users", "tts", "announcements"]
    
    db = get_db()
    perms = db.execute(
        "SELECT permission FROM user_permissions WHERE user_id = ?",
        (user_id,)
    ).fetchall()
    return [p["permission"] for p in perms]

def permission_required(permission):
    """Decorator to require a specific permission"""
    from functools import wraps
    def decorator(view):
        @wraps(view)
        def wrapped(*args, **kwargs):
            if "user_id" not in session:
                return redirect(url_for("login"))
            if not has_permission(session["user_id"], permission):
                flash("You do not have permission to access this page.", "error")
                return redirect(url_for("dashboard"))
            return view(*args, **kwargs)
        return wrapped
    return decorator

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
            return redirect(url_for("dashboard"))
        flash("Invalid username or password", "error")
    return render_template("login.html")

@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))

@app.route("/change_password", methods=["POST"])
@login_required
def change_password():
    """Change password - users can change their own, admins can change any user's password"""
    user_id = request.form.get("user_id")
    
    # If user_id is provided and current user is admin, allow changing that user's password
    # Otherwise, user can only change their own password
    if user_id and is_admin(session["user_id"]):
        target_user_id = int(user_id)
        # Admins can change any user's password without current password
        current = None
    else:
        target_user_id = session["user_id"]
        current = request.form.get("current_password", "")
    
    new = request.form.get("new_password", "")
    confirm = request.form.get("confirm_password", "")

    if not new or new != confirm:
        flash("New passwords do not match.", "error")
        return redirect(url_for("users"))

    db = get_db()
    
    # If changing own password, verify current password
    if target_user_id == session["user_id"] and current is not None:
        cur = db.execute(
            "SELECT password FROM users WHERE id = ?",
            (target_user_id,),
        )
        row = cur.fetchone()
        if not row or row["password"] != current:
            flash("Current password is incorrect.", "error")
            return redirect(url_for("users"))

    # Update the password
    db.execute(
        "UPDATE users SET password = ? WHERE id = ?",
        (new, target_user_id),
    )
    db.commit()
    
    if target_user_id == session["user_id"]:
        flash("Your password has been updated.", "success")
    else:
        user = db.execute("SELECT username FROM users WHERE id = ?", (target_user_id,)).fetchone()
        flash(f"Password updated for user '{user['username']}'.", "success")
    
    return redirect(url_for("users"))

@app.route("/admin_change_password/<int:user_id>", methods=["POST"])
@login_required
@permission_required("users")
def admin_change_password(user_id):
    """Admin-only route to change any user's password"""
    if not is_admin(session["user_id"]):
        flash("Only administrators can change other users' passwords.", "error")
        return redirect(url_for("users"))
    
    new = request.form.get("new_password", "")
    confirm = request.form.get("confirm_password", "")

    if not new or new != confirm:
        flash("New passwords do not match.", "error")
        return redirect(url_for("users"))

    db = get_db()
    user = db.execute("SELECT username FROM users WHERE id = ?", (user_id,)).fetchone()
    
    if not user:
        flash("User not found.", "error")
        return redirect(url_for("users"))

    db.execute(
        "UPDATE users SET password = ? WHERE id = ?",
        (new, user_id),
    )
    db.commit()
    flash(f"Password updated for user '{user['username']}'.", "success")
    return redirect(url_for("users"))


# ---------- dashboard ----------

@app.route("/")
def root():
    """Redirect root URL to login page"""
    return redirect(url_for("login"))

@app.route("/dashboard")
@login_required
def dashboard():
    db = get_db()
    alarm_count = db.execute("SELECT COUNT(*) as c FROM alarms").fetchone()["c"]
    enabled_count = db.execute("SELECT COUNT(*) as c FROM alarms WHERE enabled = 1").fetchone()["c"]
    
    return render_template(
        "dashboard.html",
        alarm_count=alarm_count,
        enabled_count=enabled_count,
    )


# ---------- user management ----------

@app.route("/users")
@login_required
@permission_required("users")
def users():
    db = get_db()
    users_list = db.execute(
        "SELECT id, username, role FROM users ORDER BY id"
    ).fetchall()
    
    # Get permissions for each user
    users_with_perms = []
    for user in users_list:
        perms = get_user_permissions(user["id"])
        users_with_perms.append({
            "id": user["id"],
            "username": user["username"],
            "role": user["role"],
            "permissions": perms
        })
    
    # Available permissions list
    available_permissions = ["bells", "backup", "users", "tts", "announcements"]
    
    return render_template(
        "users.html",
        users=users_with_perms,
        available_permissions=available_permissions
    )

@app.route("/add_user", methods=["POST"])
@login_required
@permission_required("users")
def add_user():
    username = request.form.get("username", "").strip()
    password = request.form.get("password", "").strip()
    role = request.form.get("role", "user").strip()
    
    # Only admins can create other admins
    if role == "admin" and not is_admin(session["user_id"]):
        flash("Only administrators can create admin users.", "error")
        return redirect(url_for("users"))
    
    if not username or not password:
        flash("Username and password are required.", "error")
        return redirect(url_for("users"))
    
    db = get_db()
    try:
        # Insert user
        cur = db.execute(
            "INSERT INTO users (username, password, role) VALUES (?, ?, ?)",
            (username, password, role),
        )
        user_id = cur.lastrowid
        
        # Add permissions if not admin
        if role != "admin":
            permissions = request.form.getlist("permissions")
            for perm in permissions:
                if perm in ["bells", "backup", "users", "tts", "announcements"]:
                    db.execute(
                        "INSERT INTO user_permissions (user_id, permission) VALUES (?, ?)",
                        (user_id, perm)
                    )
        
        db.commit()
        flash(f"User '{username}' added successfully.", "success")
    except sqlite3.IntegrityError:
        flash(f"Username '{username}' already exists.", "error")
    
    return redirect(url_for("users"))

@app.route("/delete_user/<int:user_id>")
@login_required
@permission_required("users")
def delete_user(user_id):
    # Prevent deleting yourself
    if user_id == session["user_id"]:
        flash("You cannot delete your own account.", "error")
        return redirect(url_for("users"))
    
    db = get_db()
    user = db.execute("SELECT username, role FROM users WHERE id = ?", (user_id,)).fetchone()
    if user:
        # Prevent non-admins from deleting admins
        if user["role"] == "admin" and not is_admin(session["user_id"]):
            flash("Only administrators can delete admin users.", "error")
            return redirect(url_for("users"))
        
        db.execute("DELETE FROM users WHERE id = ?", (user_id,))
        db.commit()
        flash(f"User '{user['username']}' deleted.", "success")
    
    return redirect(url_for("users"))

@app.route("/update_user_permissions/<int:user_id>", methods=["POST"])
@login_required
@permission_required("users")
def update_user_permissions(user_id):
    """Update permissions for a user"""
    db = get_db()
    user = db.execute("SELECT role FROM users WHERE id = ?", (user_id,)).fetchone()
    
    if not user:
        flash("User not found.", "error")
        return redirect(url_for("users"))
    
    # Can't change admin permissions
    if user["role"] == "admin":
        flash("Admin users have all permissions and cannot be modified.", "error")
        return redirect(url_for("users"))
    
    # Get selected permissions
    permissions = request.form.getlist("permissions")
    
    # Remove all existing permissions
    db.execute("DELETE FROM user_permissions WHERE user_id = ?", (user_id,))
    
    # Add new permissions
    for perm in permissions:
        if perm in ["bells", "backup", "users", "tts", "announcements"]:
            db.execute(
                "INSERT INTO user_permissions (user_id, permission) VALUES (?, ?)",
                (user_id, perm)
            )
    
    db.commit()
    flash("User permissions updated successfully.", "success")
    return redirect(url_for("users"))

@app.route("/update_user_role/<int:user_id>", methods=["POST"])
@login_required
@permission_required("users")
def update_user_role(user_id):
    """Update role for a user (admin only)"""
    if not is_admin(session["user_id"]):
        flash("Only administrators can change user roles.", "error")
        return redirect(url_for("users"))
    
    new_role = request.form.get("role", "user").strip()
    if new_role not in ["admin", "user"]:
        flash("Invalid role specified.", "error")
        return redirect(url_for("users"))
    
    # Prevent changing your own role
    if user_id == session["user_id"]:
        flash("You cannot change your own role.", "error")
        return redirect(url_for("users"))
    
    db = get_db()
    db.execute("UPDATE users SET role = ? WHERE id = ?", (new_role, user_id))
    
    # If changing to admin, remove all permissions (admins don't need them)
    if new_role == "admin":
        db.execute("DELETE FROM user_permissions WHERE user_id = ?", (user_id,))
    
    db.commit()
    flash("User role updated successfully.", "success")
    return redirect(url_for("users"))


# ---------- alarms ----------

@app.route("/alarms")
@login_required
@permission_required("bells")
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

    sound_files = []
    if SOUNDS_DIR.exists():
        try:
            sound_files = sorted([
                f for f in os.listdir(SOUNDS_DIR)
                if f.lower().endswith(".wav")
            ])
        except Exception:
            sound_files = []

    # Get edit parameters from URL (if editing)
    edit_day = request.args.get("edit_day")
    edit_time = request.args.get("edit_time")
    edit_sound = request.args.get("edit_sound")
    edit_enabled = request.args.get("edit_enabled")

    return render_template(
        "alarms.html",
        alarms=alarms,
        volume=volume,
        sounds=sound_files,
        edit_day=edit_day if edit_day else None,
        edit_time=edit_time if edit_time else None,
        edit_sound=edit_sound if edit_sound else None,
        edit_enabled=edit_enabled if edit_enabled else None,
    )


@app.route("/add_alarm", methods=["POST"])
@login_required
@permission_required("bells")
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

    sync_cron()
    return redirect(url_for("alarms"))


@app.route("/toggle_alarm/<int:alarm_id>")
@login_required
@permission_required("bells")
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

    sync_cron()
    return redirect(url_for("alarms"))


@app.route("/delete_alarm/<int:alarm_id>")
@login_required
@permission_required("bells")
def delete_alarm(alarm_id):
    db = get_db()
    db.execute("DELETE FROM alarms WHERE id = ?", (alarm_id,))
    db.commit()

    sync_cron()
    return redirect(url_for("alarms"))

@app.route("/edit_alarm/<int:alarm_id>")
@login_required
@permission_required("bells")
def edit_alarm(alarm_id):
    """Delete alarm and redirect to form with pre-filled values"""
    db = get_db()
    alarm = db.execute(
        "SELECT day_of_week, time_str, sound_path, enabled FROM alarms WHERE id = ?",
        (alarm_id,)
    ).fetchone()
    
    if alarm:
        # Delete the alarm
        db.execute("DELETE FROM alarms WHERE id = ?", (alarm_id,))
        db.commit()
        sync_cron()
        
        # Redirect with form data as URL parameters
        return redirect(url_for("alarms", 
            edit_day=alarm["day_of_week"],
            edit_time=alarm["time_str"],
            edit_sound=alarm["sound_path"],
            edit_enabled=alarm["enabled"]
        ))
    
    return redirect(url_for("alarms"))


@app.route("/update_alarm/<int:alarm_id>", methods=["POST"])
@login_required
@permission_required("bells")
def update_alarm(alarm_id):
    day = int(request.form["day"])
    time_str = request.form["time"]
    sound = request.form["sound"]
    enabled = 1 if request.form.get("enabled") == "on" else 0

    db = get_db()
    db.execute(
        """
        UPDATE alarms
        SET day_of_week=?, time_str=?, sound_path=?, enabled=?
        WHERE id=?
        """,
        (day, time_str, sound, enabled, alarm_id),
    )
    db.commit()

    sync_cron()
    return redirect(url_for("alarms"))


# ---------- sound management ----------

@app.route("/test_sound/<path:filename>")
@login_required
@permission_required("bells")
def test_sound(filename):
    sound_path = f"sounds/{filename}"
    result = play_sound(sound_path)
    # Return debug info if available
    if result and isinstance(result, dict) and result.get("error"):
        return result.get("message", "Error playing sound"), 500
    return ("", 204)

@app.route("/upload_sound", methods=["POST"])
@login_required
@permission_required("bells")
def upload_sound():
    file = request.files.get("file")
    if file and file.filename.lower().endswith(".wav"):
        if not SOUNDS_DIR.exists():
            SOUNDS_DIR.mkdir(parents=True, exist_ok=True)
        dest = SOUNDS_DIR / file.filename
        file.save(dest)
    return redirect(url_for("alarms"))

@app.route("/delete_sound/<path:filename>")
@login_required
@permission_required("bells")
def delete_sound(filename):
    path = SOUNDS_DIR / filename
    if path.exists():
        path.unlink()
    return redirect(url_for("alarms"))


# ---------- volume ----------

@app.route("/set_volume", methods=["POST"])
@login_required
@permission_required("bells")
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


# ---------- playback ----------
# NOTE: Uses pw-play (PipeWire). aplay (ALSA) is NOT supported in future Pi3 builds.

def play_sound(sound_path):
    """Play sound file using pw-play. Returns dict with debug info on error."""
    full_path = str((APP_DIR / sound_path).resolve())
    
    # Debug: Log the command
    cmd = ["pw-play", full_path]
    print(f"[DEBUG] Executing: {' '.join(cmd)}", flush=True)
    
    if not os.path.exists(full_path):
        error_msg = f"File not found: {full_path}"
        print(f"[ERROR] {error_msg}", flush=True)
        return {"error": True, "message": error_msg, "command": " ".join(cmd)}
    
    # Get the current user's environment for PipeWire session
    import pwd
    current_user = pwd.getpwuid(os.getuid()).pw_name
    user_home = pwd.getpwuid(os.getuid()).pw_dir
    
    # Set up environment for PipeWire user session
    env = os.environ.copy()
    env["XDG_RUNTIME_DIR"] = f"/run/user/{os.getuid()}"
    env["HOME"] = user_home
    env["USER"] = current_user
    
    try:
        # Capture stderr to see any errors
        result = subprocess.run(
            cmd,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=10,
            env=env
        )
        
        if result.returncode != 0:
            error_msg = f"pw-play failed (exit code {result.returncode}): {result.stderr}"
            print(f"[ERROR] {error_msg}", flush=True)
            print(f"[DEBUG] User: {current_user}, UID: {os.getuid()}, XDG_RUNTIME_DIR: {env.get('XDG_RUNTIME_DIR')}", flush=True)
            return {
                "error": True, 
                "message": error_msg, 
                "command": " ".join(cmd),
                "stderr": result.stderr
            }
        
        print(f"[SUCCESS] Sound played: {full_path}", flush=True)
        return None
    except subprocess.TimeoutExpired:
        error_msg = f"pw-play timed out after 10 seconds"
        print(f"[ERROR] {error_msg}", flush=True)
        return {"error": True, "message": error_msg, "command": " ".join(cmd)}
    except Exception as e:
        error_msg = f"Exception running pw-play: {str(e)}"
        print(f"[ERROR] {error_msg}", flush=True)
        import traceback
        print(f"[ERROR] Traceback: {traceback.format_exc()}", flush=True)
        return {"error": True, "message": error_msg, "command": " ".join(cmd)}


# ---------- backup and restore ----------

@app.route("/backup")
@login_required
@permission_required("backup")
def backup_page():
    """Display backup and restore page"""
    # Ensure backup directory exists
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    
    # List existing backups
    backups = []
    if BACKUP_DIR.exists():
        for backup_file in sorted(BACKUP_DIR.glob("churchbells-backup-*.zip"), reverse=True):
            try:
                stat = backup_file.stat()
                backups.append({
                    "filename": backup_file.name,
                    "size": stat.st_size,
                    "created": datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
                })
            except Exception:
                pass
    
    return render_template("backup.html", backups=backups)


@app.route("/create_backup", methods=["POST"])
@login_required
@permission_required("backup")
def create_backup():
    """Create a new backup including database alarms and sound files"""
    try:
        # Ensure backup directory exists
        BACKUP_DIR.mkdir(parents=True, exist_ok=True)
        
        # Generate timestamp
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        backup_file = BACKUP_DIR / f"churchbells-backup-{timestamp}.zip"
        
        # Export alarms from database to JSON
        db = get_db()
        alarms = db.execute(
            "SELECT id, day_of_week, time_str, sound_path, enabled, last_run_date FROM alarms"
        ).fetchall()
        
        alarms_data = [dict(row) for row in alarms]
        alarms_json = json.dumps(alarms_data, indent=2)
        
        # Create ZIP archive
        with zipfile.ZipFile(backup_file, 'w', zipfile.ZIP_DEFLATED) as zipf:
            # Add alarms JSON
            zipf.writestr("alarms.json", alarms_json)
            
            # Add all sound files
            if SOUNDS_DIR.exists():
                for sound_file in SOUNDS_DIR.rglob("*"):
                    if sound_file.is_file():
                        arcname = sound_file.relative_to(SOUNDS_DIR.parent)
                        zipf.write(sound_file, arcname)
        
        flash(f"Backup created successfully: {backup_file.name}", "success")
    except Exception as e:
        flash(f"Error creating backup: {str(e)}", "error")
    
    return redirect(url_for("backup_page"))


@app.route("/download_backup/<filename>")
@login_required
@permission_required("backup")
def download_backup(filename):
    """Download a backup file"""
    backup_file = BACKUP_DIR / filename
    
    # Security check: ensure file is in backup directory
    if not backup_file.exists() or not str(backup_file).startswith(str(BACKUP_DIR)):
        flash("Backup file not found", "error")
        return redirect(url_for("backup_page"))
    
    return send_file(
        backup_file,
        as_attachment=True,
        download_name=filename,
        mimetype="application/zip"
    )


@app.route("/delete_backup/<filename>")
@login_required
def delete_backup(filename):
    """Delete a backup file"""
    backup_file = BACKUP_DIR / filename
    
    # Security check: ensure file is in backup directory
    if not backup_file.exists() or not str(backup_file).startswith(str(BACKUP_DIR)):
        flash("Backup file not found", "error")
        return redirect(url_for("backup_page"))
    
    try:
        backup_file.unlink()
        flash(f"Backup '{filename}' deleted", "success")
    except Exception as e:
        flash(f"Error deleting backup: {str(e)}", "error")
    
    return redirect(url_for("backup_page"))


@app.route("/restore_backup", methods=["POST"])
@login_required
@permission_required("backup")
def restore_backup():
    """Upload and restore a backup file"""
    if "backup_file" not in request.files:
        flash("No backup file provided", "error")
        return redirect(url_for("backup_page"))
    
    file = request.files["backup_file"]
    if file.filename == "":
        flash("No backup file selected", "error")
        return redirect(url_for("backup_page"))
    
    if not file.filename.lower().endswith(".zip"):
        flash("Backup file must be a ZIP file", "error")
        return redirect(url_for("backup_page"))
    
    try:
        # Save uploaded file temporarily
        temp_backup = BACKUP_DIR / f"temp-restore-{datetime.now().strftime('%Y%m%d-%H%M%S')}.zip"
        file.save(temp_backup)
        
        # Stop the service before restore
        try:
            subprocess.run(
                ["sudo", "systemctl", "stop", "churchbell.service"],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass
        
        # Extract backup
        with zipfile.ZipFile(temp_backup, 'r') as zipf:
            # Extract alarms.json
            if "alarms.json" in zipf.namelist():
                zipf.extract("alarms.json", APP_DIR)
                
                # Restore alarms to database
                alarms_json_path = APP_DIR / "alarms.json"
                with open(alarms_json_path, 'r') as f:
                    alarms_data = json.load(f)
                
                db = get_db()
                # Clear existing alarms
                db.execute("DELETE FROM alarms")
                db.commit()
                
                # Insert restored alarms (without IDs to let SQLite auto-increment)
                for alarm in alarms_data:
                    db.execute(
                        """
                        INSERT INTO alarms (day_of_week, time_str, sound_path, enabled, last_run_date)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                        (
                            alarm.get("day_of_week"),
                            alarm.get("time_str"),
                            alarm.get("sound_path"),
                            alarm.get("enabled", 1),
                            alarm.get("last_run_date")
                        )
                    )
                db.commit()
                
                # Clean up temporary JSON file
                alarms_json_path.unlink()
            
            # Extract sound files
            for member in zipf.namelist():
                if member.startswith("sounds/"):
                    zipf.extract(member, APP_DIR)
        
        # Clean up temp backup file
        temp_backup.unlink()
        
        # Sync cron with restored alarms
        sync_cron()
        
        # Restart the service
        try:
            subprocess.run(
                ["sudo", "systemctl", "start", "churchbell.service"],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass
        
        flash("Backup restored successfully. Service restarted.", "success")
    except Exception as e:
        flash(f"Error restoring backup: {str(e)}", "error")
        # Try to restart service even on error
        try:
            subprocess.run(
                ["sudo", "systemctl", "start", "churchbell.service"],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass
    
    return redirect(url_for("backup_page"))


# ---------- main ----------

if __name__ == "__main__":
    if not SOUNDS_DIR.exists():
        SOUNDS_DIR.mkdir(parents=True, exist_ok=True)
    if not BACKUP_DIR.exists():
        BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    try:
        init_db()
    except Exception as e:
        print(f"Warning: Database initialization issue: {e}")
    
    # SSL certificate paths
    CERT_DIR = APP_DIR / "ssl"
    CERT_FILE = CERT_DIR / "cert.pem"
    KEY_FILE = CERT_DIR / "key.pem"
    
    # Check if certificates exist
    if CERT_FILE.exists() and KEY_FILE.exists():
        import ssl
        try:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(str(CERT_FILE), str(KEY_FILE))
            print(f"Starting HTTPS server on port 8080 with SSL certificates")
            app.run(host="0.0.0.0", port=8080, debug=False, threaded=True, ssl_context=context)
        except Exception as e:
            print(f"ERROR: Failed to create SSL context: {e}")
            print(f"Starting HTTP server (insecure) - SSL required for production")
            app.run(host="0.0.0.0", port=8080, debug=False, threaded=True)
    else:
        print(f"ERROR: SSL certificates not found at {CERT_FILE} and {KEY_FILE}")
        print(f"Please run: ./generate_ssl_cert.sh")
        print(f"Starting HTTP server (insecure) - SSL required for production")
        app.run(host="0.0.0.0", port=8080, debug=False, threaded=True)
