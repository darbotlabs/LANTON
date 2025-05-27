#!/usr/bin/env python
# filepath: d:\0GH_PROD\Darbot_Labs\darbot-LANton\lib\omniparser\local_agent.py
#
# Mock OmniParser agent for testing LANton integration

import argparse
import http.server
import json
import socketserver
import os
import sys
from datetime import datetime

class OmniParserHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
        response = {
            "service": "OmniParser",
            "version": "0.9.2",
            "status": "ready",
            "capabilities": ["text", "json", "xml", "markdown"],
            "timestamp": datetime.now().isoformat()
        }
        
        self.wfile.write(json.dumps(response, indent=2).encode())
    
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
        try:
            request = json.loads(post_data)
            response = {
                "service": "OmniParser",
                "parsed": True,
                "input_type": request.get("type", "unknown"),
                "output": "Successfully parsed your input",
                "timestamp": datetime.now().isoformat()
            }
        except:
            response = {
                "service": "OmniParser",
                "parsed": False,
                "error": "Failed to parse input",
                "timestamp": datetime.now().isoformat()
            }
        
        self.wfile.write(json.dumps(response, indent=2).encode())
        
    def log_message(self, format, *args):
        print(f"[OmniParser] - {format%args}")

def main():
    parser = argparse.ArgumentParser(description='Mock OmniParser Agent')
    parser.add_argument('--port', type=int, default=8800, 
                        help='Port to run the server on (can also be set with OMNIPARSER_PORT env var)')
    args = parser.parse_args()
    
    # Check if port is set in environment variable
    if 'OMNIPARSER_PORT' in os.environ:
        try:
            port = int(os.environ['OMNIPARSER_PORT'])
        except ValueError:
            port = args.port
    else:
        port = args.port
    
    try:
        with socketserver.TCPServer(("", port), OmniParserHandler) as httpd:
            print(f"OmniParser agent started at port {port}")
            print(f"PID: {os.getpid()}")
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("OmniParser agent shutting down")
        sys.exit(0)
    except Exception as e:
        print(f"Error starting OmniParser agent: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
