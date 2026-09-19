# -*- coding: utf-8 -*-
"""
Client interface for the Antigravity Fusion 360 Live Bridge.
Provides programmatic and CLI access to dispatch modeling commands to Autodesk Fusion 360.
"""

import sys
import os
import json
import argparse
import urllib.request
import urllib.error

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 9876


class FusionBridgeClient:
    def __init__(self, host=DEFAULT_HOST, port=DEFAULT_PORT):
        self.base_url = f"http://{host}:{port}"

    def ping(self):
        """Check if Fusion 360 bridge is running and return document/product status."""
        try:
            req = urllib.request.Request(f"{self.base_url}/ping")
            with urllib.request.urlopen(req, timeout=3) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                return True, data
        except urllib.error.URLError as e:
            return False, f"Cannot connect to Fusion 360 Bridge ({e}). Is Fusion open and the Add-In running?"
        except Exception as e:
            return False, f"Ping error: {e}"

    def execute_code(self, code: str, timeout: float = 60.0):
        """Send Python code to execute on Fusion's main thread."""
        try:
            payload = json.dumps({
                "code": code,
                "timeout": timeout
            }).encode('utf-8')

            req = urllib.request.Request(
                f"{self.base_url}/execute",
                data=payload,
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=timeout + 5) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                return data
        except urllib.error.URLError as e:
            return {
                "success": False,
                "error": f"Connection failed to {self.base_url}: {e}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Execution request exception: {e}"
            }

    def execute_file(self, file_path: str, timeout: float = 60.0):
        """Read a Python file and send it to Fusion 360 for execution."""
        if not os.path.exists(file_path):
            return {"success": False, "error": f"File not found: {file_path}"}

        with open(file_path, "r", encoding="utf-8") as f:
            code = f.read()

        return self.execute_code(code, timeout=timeout)


def main():
    parser = argparse.ArgumentParser(description="Antigravity Fusion 360 Bridge CLI Client")
    parser.add_argument("--host", default=DEFAULT_HOST, help="Bridge host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Bridge port (default: 9876)")
    parser.add_argument("--ping", action="store_true", help="Ping Fusion 360 bridge and check status")
    parser.add_argument("--file", "-f", help="Execute a Python script file in Fusion 360")
    parser.add_argument("--eval", "-e", help="Evaluate a Python code snippet directly in Fusion 360")
    parser.add_argument("--timeout", type=float, default=60.0, help="Execution timeout in seconds")

    args = parser.parse_args()
    client = FusionBridgeClient(host=args.host, port=args.port)

    if args.ping:
        ok, res = client.ping()
        if ok:
            print("=== Fusion 360 Bridge ONLINE ===")
            print(json.dumps(res, indent=2))
            sys.exit(0)
        else:
            print(f"=== Fusion 360 Bridge OFFLINE ===")
            print(res)
            sys.exit(1)

    if args.file:
        print(f"Dispatching script '{args.file}' to Fusion 360...")
        res = client.execute_file(args.file, timeout=args.timeout)
        print("=== Result ===")
        print(f"Success: {res.get('success')}")
        if res.get('output'):
            print(f"[STDOUT]:\n{res['output']}")
        if res.get('error'):
            print(f"[ERROR]:\n{res['error']}")
        sys.exit(0 if res.get('success') else 1)

    if args.eval:
        print(f"Evaluating snippet in Fusion 360...")
        res = client.execute_code(args.eval, timeout=args.timeout)
        print("=== Result ===")
        print(f"Success: {res.get('success')}")
        if res.get('output'):
            print(f"[STDOUT]:\n{res['output']}")
        if res.get('error'):
            print(f"[ERROR]:\n{res['error']}")
        sys.exit(0 if res.get('success') else 1)

    parser.print_help()


if __name__ == "__main__":
    main()
