#!/usr/bin/env python
# filepath: d:\0GH_PROD\Darbot_Labs\darbot-LANton\lib\flask-gui\darbot_server.py
#
# Mock Flask GUI server for testing LANton integration

from flask import Flask, jsonify, render_template_string
import os
import sys

app = Flask(__name__)

# Simple HTML template for the mock GUI
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Darbot Flask GUI</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            background-color: #1a1a1a;
            color: #e0e0e0;
            margin: 0;
            padding: 20px;
            line-height: 1.6;
        }
        h1 {
            color: #00aaff;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: #252525;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.5);
        }
        .status {
            padding: 10px;
            background-color: #0055aa;
            color: white;
            border-radius: 3px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Darbot Flask GUI</h1>
        <p>This is a mock Flask GUI for testing LANton integration.</p>
        <div class="status">
            <p>Server is running on port: {{ port }}</p>
            <p>Managed by LANton - Port assigned dynamically</p>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def index():
    port = os.environ.get('FLASK_PORT', '5000')
    return render_template_string(HTML_TEMPLATE, port=port)

@app.route('/api/status')
def status():
    return jsonify({
        'service': 'Flask GUI',
        'status': 'running',
        'port': os.environ.get('FLASK_PORT', '5000')
    })

if __name__ == '__main__':
    # Get port from environment or use default
    port = int(os.environ.get('FLASK_PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
