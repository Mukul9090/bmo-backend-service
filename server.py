import os
from flask import Flask, jsonify

app = Flask(__name__)

# Read CLUSTER_ROLE from environment variable, default to "unknown"
CLUSTER_ROLE = os.getenv('CLUSTER_ROLE', 'unknown')


@app.route('/healthz', methods=['GET'])
def healthz():
    """Health check endpoint."""
    return jsonify({
        "status": "ok",
        "role": CLUSTER_ROLE
    }), 200


@app.route('/', methods=['GET'])
def root():
    """Root endpoint."""
    return jsonify({
        "message": "backend-service running",
        "role": CLUSTER_ROLE
    }), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)

