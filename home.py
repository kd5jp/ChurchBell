from flask import Flask

app = Flask(__name__)

@app.route("/")
def index():
    return """
    <html>
      <head>
        <title>Church Bells Home</title>
        <style>
          body {
            font-family: sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            background: #f0f0f0;
          }
          .card {
            padding: 30px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 0 10px rgba(0,0,0,0.2);
            text-align: center;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <h2>Work in Progress</h2>
          <p>This will become the main home page.</p>
          <p><a href="http://localhost:8080">Go to Bell Scheduler</a></p>
        </div>
      </body>
    </html>
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
