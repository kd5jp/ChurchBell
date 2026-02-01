from flask import Flask, request, redirect
import subprocess

app = Flask(__name__)

def get_service_status(service):
    try:
        status = subprocess.run(
            ["systemctl", "is-active", service],
            capture_output=True,
            text=True
        ).stdout.strip()
    except Exception:
        status = "unknown"

    try:
        logs = subprocess.run(
            ["journalctl", "-u", service, "-n", "10", "--no-pager"],
            capture_output=True,
            text=True
        ).stdout
    except Exception:
        logs = "No logs available."

    return status, logs


@app.route("/")
def index():
    # Redirect to port 8080 login
    host = request.host.split(":")[0]
    from flask import redirect
    return redirect(f"http://{host}:8080/login", code=302)

    # Get service statuses
    home_status, home_logs = get_service_status("churchbell-home.service")
    sched_status, sched_logs = get_service_status("churchbell.service")

    # Color helpers
    def colorize(status):
        if status == "active":
            return f'<span style="color: green; font-weight: bold;">{status}</span>'
        return f'<span style="color: red; font-weight: bold;">{status}</span>'

    return f"""
<html>
  <head>
    <title>ChurchBell Dashboard</title>
    <style>
      body {{
        font-family: sans-serif;
        background: #f0f0f0;
        margin: 0;
        padding: 40px;
      }}
      .card {{
        background: white;
        padding: 20px;
        border-radius: 8px;
        margin-bottom: 20px;
        box-shadow: 0 0 10px rgba(0,0,0,0.15);
      }}
      pre {{
        background: #eee;
        padding: 10px;
        border-radius: 6px;
        overflow-x: auto;
      }}
      a {{
        text-decoration: none;
        color: #0066cc;
        font-weight: bold;
      }}
    </style>
  </head>

  <body>

    <div class="card">
      <h2>ChurchBell System Dashboard</h2>
      <p><a href="{scheduler_url}">Go to Bell Scheduler</a></p>
    </div>

    <div class="card">
      <h3>Home Service (Port 80)</h3>
      <p>Status: {colorize(home_status)}</p>
      <pre>{home_logs}</pre>
    </div>

    <div class="card">
      <h3>Scheduler Service (Port 8080)</h3>
      <p>Status: {colorize(sched_status)}</p>
      <pre>{sched_logs}</pre>
    </div>

  </body>
</html>
"""


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=False)
