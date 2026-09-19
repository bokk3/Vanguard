# -*- coding: utf-8 -*-
"""
Blender Live Bridge Client for Antigravity.
Connects to Blender's embedded HTTP server on port 9877.
"""

import sys
import os
import json
import argparse
import urllib.request
import urllib.error

DEFAULT_BRIDGE_URL = "http://127.0.0.1:9877"


class BlenderBridgeClient:
    def __init__(self, base_url=DEFAULT_BRIDGE_URL):
        self.base_url = base_url.rstrip("/")

    def ping(self):
        url = f"{self.base_url}/ping"
        try:
            req = urllib.request.Request(url, method="GET")
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                return True, data
        except Exception as e:
            return False, str(e)

    def execute_code(self, python_code, timeout=60.0):
        url = f"{self.base_url}/execute"
        payload = json.dumps({"code": python_code}).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="ignore")
            try:
                return json.loads(err_body)
            except:
                return {"success": False, "error": f"HTTP {e.code}: {err_body}"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def execute_file(self, file_path, timeout=60.0):
        if not os.path.exists(file_path):
            return {"success": False, "error": f"File not found: {file_path}"}
        with open(file_path, "r", encoding="utf-8") as f:
            code = f.read()
        return self.execute_code(code, timeout=timeout)


def main():
    parser = argparse.ArgumentParser(description="Antigravity Blender Bridge Client")
    parser.add_argument("--ping", action="store_true", help="Ping Blender bridge server")
    parser.add_argument("--code", "-c", help="Execute inline Python string in Blender")
    parser.add_argument("--file", "-f", help="Execute Python script file in Blender")
    parser.add_argument("--url", default=DEFAULT_BRIDGE_URL, help="Bridge server URL (default: http://127.0.0.1:9877)")

    args = parser.parse_args()
    client = BlenderBridgeClient(args.url)

    if args.ping:
        online, res = client.ping()
        if online:
            print("=== Blender Bridge ONLINE ===")
            print(json.dumps(res, indent=2))
            sys.exit(0)
        else:
            print(f"=== Blender Bridge OFFLINE ===\nError: {res}")
            sys.exit(1)

    if args.code:
        print(f"Dispatching inline code to Blender...")
        res = client.execute_code(args.code)
        print("=== Result ===")
        print(f"Success: {res.get('success')}")
        if res.get('output'):
            print(f"[STDOUT]:\n{res['output']}")
        if res.get('error'):
            print(f"[ERROR]:\n{res['error']}")
        sys.exit(0 if res.get("success") else 1)

    if args.file:
        print(f"Dispatching script '{args.file}' to Blender...")
        res = client.execute_file(args.file)
        print("=== Result ===")
        print(f"Success: {res.get('success')}")
        if res.get('output'):
            print(f"[STDOUT]:\n{res['output']}")
        if res.get('error'):
            print(f"[ERROR]:\n{res['error']}")
        sys.exit(0 if res.get("success") else 1)

    parser.print_help()


if __name__ == "__main__":
    main()
