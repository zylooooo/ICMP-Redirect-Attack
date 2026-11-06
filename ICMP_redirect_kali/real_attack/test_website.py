#!/usr/bin/python3
from flask import Flask
import os

# Check if running as root
if os.geteuid() != 0:
    print("[-] This script must be run as root!")
    exit(1)

app = Flask(__name__)

# Simple HTML content
HTML_CONTENT = """
<!DOCTYPE html>
<html>
<head>
    <title>ICMP Redirect Test</title>
    <style>
        body { 
            font-family: Arial; 
            text-align: center; 
            margin-top: 50px; 
            background: #f0f0f0; 
        }
        .container { 
            background: white; 
            padding: 20px; 
            margin: auto; 
            max-width: 600px; 
            border-radius: 10px; 
        }
        h1 { color: red; }
    </style>
</head>
<body>
    <div class="container">
        <h1>ICMP Redirect Successful!</h1>
        <p>Your traffic has been intercepted.</p>
        <p>Original request has been redirected to this test page.</p>
    </div>
</body>
</html>
"""

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def catch_all(path):
    print(f"[+] Received request for: /{path}")
    return HTML_CONTENT

if __name__ == '__main__':
    try:
        print("[+] Starting test website on port 80...")
        app.run(host='0.0.0.0', port=80)
    except Exception as e:
        print(f"[-] Error: {e}")
