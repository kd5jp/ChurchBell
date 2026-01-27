from flask import Flask, request

app = Flask(__name__)

@app.route("/")
def index():
    # Build a dynamic link to the scheduler using the current host
    host = request.host.split(":")[0]
    scheduler_url = f"http://{host}:8080"

    return f"""
<html>
  <head>
    <title>Church Bells Home</title>
    <style>
      body {{
        font-family: sans-serif;
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100vh;
        background: #f0f0f0;
        margin: 0;
      }}
      .card {{
        padding: 30px;
        background: white;
        border-radius: 8px;
        box-shadow: 0 0 10px rgba(0,0,0,0.2);
        text-align: center;
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
      <h2>Work in Progress</h2>
      <p>This will become the main home page.</p>
      <p><a href="{scheduler_url}">Go to Bell Scheduler</a></p>
    </div>
  </body>
</html>
"""

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=False)
