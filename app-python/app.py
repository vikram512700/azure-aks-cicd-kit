# =============================================================================
# Python Flask App
# =============================================================================
# Endpoints:
#   GET /        → greeting + secret status
#   GET /health  → health check (liveness/readiness probe target)
# =============================================================================

import os
from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    """Main endpoint — shows app info and whether the KV secret is mounted."""
    secret_value = os.environ.get("PYTHON_APP_SECRET")
    return jsonify({
        "app": "python-flask",
        "version": "1.0.0",
        "message": "Hello from the Python Flask app! 🐍",
        "secret_mounted": secret_value is not None,
        "secret_preview": f"{secret_value[:4]}****" if secret_value else "NOT_SET",
    })


@app.route("/health")
def health():
    """Health check endpoint for Kubernetes liveness/readiness probes."""
    return jsonify({"status": "healthy"}), 200


# ---------------------------------------------------------------------------
# Run with gunicorn in production (see Dockerfile CMD).
# This block is for local development only.
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
