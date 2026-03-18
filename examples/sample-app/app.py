"""
Minimal Flask application that serves as the workload for this Helm lab.
Provides /healthz and /ready probes and a simple JSON response on /.
"""

import os
from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify(
        message="Hello from webapp!",
        environment=os.getenv("APP_ENV", "unknown"),
        version=os.getenv("APP_VERSION", "1.0.0"),
    )


@app.route("/healthz")
def healthz():
    return jsonify(status="healthy"), 200


@app.route("/ready")
def ready():
    return jsonify(status="ready"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
