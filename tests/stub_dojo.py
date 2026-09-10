#!/usr/bin/env python3
"""A stand-in DefectDojo instance for exercising dd-api without a real server.

Run as:  stub_dojo.py <port> <mode>

Modes:
  pro          Pro instance, valid token, synchronous import
  pro-async    Pro instance, valid token, background import that finishes
  pro-failing  Pro instance, background import that ends in Failed
  oss          open source instance: /api/mcp/ does not exist (404)
  no-priority  passes the Pro probe but serves findings without the priority
               field, the shape a defeated edition gate sees against open source
  expired      Pro instance that rejects the token with 401

The stub asserts the auth header format itself, so a regression to "Bearer"
shows up as an authentication failure in the tests rather than silently
passing.
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = "pro"
VALID_TOKEN = "0123456789abcdef0123456789abcdef01234567"
# How many times the test status has been polled, used to simulate an import
# that is still processing on the first look and terminal on the next.
POLL_COUNT = {"n": 0}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _auth_ok(self):
        header = self.headers.get("Authorization", "")
        if MODE == "expired":
            return False
        # DefectDojo uses the "Token" scheme, never "Bearer".
        if not header.startswith("Token "):
            return False
        return header.split(" ", 1)[1].strip() == VALID_TOKEN

    def do_GET(self):
        path = self.path.split("?", 1)[0]

        if path.startswith("/api/mcp/"):
            if MODE == "oss":
                return self._send(404, {"detail": "Not found."})
            if not self._auth_ok():
                return self._send(401, {"detail": "Invalid token."})
            if path == "/api/mcp/defectdojo_information/version/":
                return self._send(200, {"version": "3.3.0"})
            if path == "/api/mcp/defectdojo_information/feature_flags/":
                return self._send(200, [{"id": "reachability", "value": True}])
            return self._send(404, {"detail": "Not found."})

        if not self._auth_ok():
            return self._send(401, {"detail": "Invalid token."})

        if path == "/api/v2/user_profile/":
            return self._send(200, {"username": "tester", "email": "tester@example.com"})

        if path.startswith("/api/v2/tests/"):
            POLL_COUNT["n"] += 1
            if POLL_COUNT["n"] < 2:
                status = "Processing"
            else:
                status = "Failed" if MODE == "pro-failing" else "Processed"
            return self._send(200, {"id": 77, "status": status})

        if path == "/api/v2/findings/":
            finding = {"id": 4711, "title": "SQL Injection"}
            if MODE != "no-priority":
                finding["priority"] = 92
            return self._send(200, {"count": 1, "results": [finding]})

        return self._send(404, {"detail": "Not found."})

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            self.rfile.read(length)

        if not self._auth_ok():
            return self._send(401, {"detail": "Invalid token."})

        if path in ("/api/v2/import-scan/", "/api/v2/reimport-scan/"):
            background = MODE in ("pro-async", "pro-failing")
            return self._send(201, {
                "test": 77,
                "test_id": 77,
                "engagement_id": 12,
                "product_id": 5,
                "product_type_id": 1,
                "message": "processing",
                "background_import": background,
            })

        if path.endswith("/close/"):
            return self._send(200, {"id": 4711, "active": False, "is_mitigated": True})
        if path.endswith("/verify/"):
            return self._send(200, {"id": 4711, "verified": True})
        if path.endswith("/notes/"):
            return self._send(201, {"id": 900, "entry": "recorded"})

        return self._send(404, {"detail": "Not found."})


if __name__ == "__main__":
    port = int(sys.argv[1])
    MODE = sys.argv[2] if len(sys.argv) > 2 else "pro"
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
