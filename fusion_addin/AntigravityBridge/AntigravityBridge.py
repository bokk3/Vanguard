# -*- coding: utf-8 -*-
"""
Antigravity Bridge Add-In for Autodesk Fusion 360
Enables real-time remote modeling, programmatic scene generation, and asset export.
"""

import sys
import io
import os
import json
import uuid
import logging
import threading
import traceback
from http.server import HTTPServer, BaseHTTPRequestHandler

import adsk.core
import adsk.fusion

# Global references to prevent garbage collection by Fusion's Python runtime
_app = None
_ui = None
_customEvent = None
_handlers = []
_httpd = None
_server_thread = None
_pending_requests = {}
_requests_lock = threading.Lock()

BRIDGE_HOST = '127.0.0.1'
BRIDGE_PORT = 9876
CUSTOM_EVENT_ID = 'AntigravityBridgeExecuteEvent'


class BridgeCustomEventHandler(adsk.core.CustomEventHandler):
    """
    Executes tasks safely on Autodesk Fusion's main UI thread.
    All geometry creation and document modifications must occur here.
    """
    def __init__(self):
        super().__init__()

    def notify(self, args):
        global _app, _ui, _pending_requests, _requests_lock
        req_id = None
        try:
            eventArgs = adsk.core.CustomEventArgs.cast(args)
            if not eventArgs:
                return

            req_id = eventArgs.additionalInfo
            with _requests_lock:
                req_data = _pending_requests.get(req_id)

            if not req_data:
                return

            code_to_exec = req_data.get('code', '')
            
            # Prepare execution environment
            stdout_capture = io.StringIO()
            stderr_capture = io.StringIO()
            old_stdout = sys.stdout
            old_stderr = sys.stderr
            sys.stdout = stdout_capture
            sys.stderr = stderr_capture

            success = True
            error_msg = None

            try:
                design = None
                if _app.activeProduct:
                    design = adsk.fusion.Design.cast(_app.activeProduct)

                exec_globals = {
                    'adsk': adsk,
                    'core': adsk.core,
                    'fusion': adsk.fusion,
                    'app': _app,
                    'ui': _ui,
                    'design': design,
                    'rootComp': design.rootComponent if design else None,
                }
                
                # Execute the received script on the main UI thread
                exec(code_to_exec, exec_globals)
            except Exception as e:
                success = False
                error_msg = traceback.format_exc()
            finally:
                sys.stdout = old_stdout
                sys.stderr = old_stderr

            output_str = stdout_capture.getvalue()
            err_str = stderr_capture.getvalue()
            if err_str:
                output_str = f"{output_str}\n[STDERR]: {err_str}" if output_str else err_str

            req_data['result'] = {
                'success': success,
                'output': output_str.strip(),
                'error': error_msg
            }
            req_data['done'].set()

        except Exception as outer_e:
            if req_id:
                with _requests_lock:
                    req_data = _pending_requests.get(req_id)
                if req_data:
                    req_data['result'] = {
                        'success': False,
                        'output': '',
                        'error': f"Fatal bridge handler error: {traceback.format_exc()}"
                    }
                    req_data['done'].set()


class BridgeRequestHandler(BaseHTTPRequestHandler):
    """HTTP handler to receive commands from Antigravity."""

    def log_message(self, format, *args):
        # Silence default HTTP server console logging to avoid clutter
        return

    def _set_headers(self, status=200, content_type='application/json'):
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(204)

    def do_GET(self):
        global _app
        if self.path == '/ping' or self.path == '/':
            try:
                active_doc_name = _app.activeDocument.name if (_app and _app.activeDocument) else None
                design_type = None
                if _app and _app.activeProduct:
                    design = adsk.fusion.Design.cast(_app.activeProduct)
                    if design:
                        design_type = "Design (Active)"

                payload = {
                    'status': 'online',
                    'bridge_version': '1.0.0',
                    'fusion_version': _app.version if _app else 'unknown',
                    'active_document': active_doc_name,
                    'product_type': design_type
                }
                self._set_headers(200)
                self.wfile.write(json.dumps(payload, indent=2).encode('utf-8'))
            except Exception as e:
                self._set_headers(500)
                self.wfile.write(json.dumps({'error': str(e)}).encode('utf-8'))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({'error': 'Endpoint not found'}).encode('utf-8'))

    def do_POST(self):
        global _app, _customEvent, _pending_requests, _requests_lock
        if self.path == '/execute':
            try:
                content_length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(content_length).decode('utf-8')
                data = json.loads(body)
                code = data.get('code', '')
                timeout = float(data.get('timeout', 60.0))

                if not code:
                    self._set_headers(400)
                    self.wfile.write(json.dumps({'error': 'No code provided in request'}).encode('utf-8'))
                    return

                req_id = str(uuid.uuid4())
                done_event = threading.Event()
                req_data = {
                    'code': code,
                    'done': done_event,
                    'result': None
                }

                with _requests_lock:
                    _pending_requests[req_id] = req_data

                # Dispatch execution safely to Fusion's main thread
                _app.fireCustomEvent(CUSTOM_EVENT_ID, req_id)

                # Wait for main UI thread execution
                completed = done_event.wait(timeout=timeout)

                with _requests_lock:
                    final_data = _pending_requests.pop(req_id, None)

                if not completed:
                    self._set_headers(504)
                    self.wfile.write(json.dumps({
                        'success': False,
                        'error': f"Execution timed out after {timeout} seconds on Fusion main thread."
                    }).encode('utf-8'))
                    return

                result = final_data.get('result') if final_data else {
                    'success': False,
                    'error': 'Missing execution result'
                }
                self._set_headers(200)
                self.wfile.write(json.dumps(result, indent=2).encode('utf-8'))

            except Exception as e:
                self._set_headers(500)
                self.wfile.write(json.dumps({
                    'success': False,
                    'error': f"Server error: {traceback.format_exc()}"
                }).encode('utf-8'))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({'error': 'Endpoint not found'}).encode('utf-8'))


def start_server():
    global _httpd
    try:
        _httpd = HTTPServer((BRIDGE_HOST, BRIDGE_PORT), BridgeRequestHandler)
        _httpd.serve_forever()
    except Exception as e:
        if _ui:
            _ui.messageBox(f"Antigravity Bridge HTTP Server error: {e}")


def run(context):
    """Called by Fusion 360 when the Add-In is loaded/started."""
    global _app, _ui, _customEvent, _handlers, _server_thread
    try:
        _app = adsk.core.Application.get()
        _ui = _app.userInterface

        # Register custom event on Fusion's event bus
        _customEvent = _app.registerCustomEvent(CUSTOM_EVENT_ID)
        onExecute = BridgeCustomEventHandler()
        _customEvent.add(onExecute)
        _handlers.append(onExecute)

        # Start the background HTTP listener
        _server_thread = threading.Thread(target=start_server, daemon=True)
        _server_thread.start()

        # Display non-blocking notification in Fusion
        if _ui:
            _ui.messageBox(
                f"Antigravity Bridge started successfully!\n\n"
                f"Listening for modeling instructions at:\nhttp://{BRIDGE_HOST}:{BRIDGE_PORT}\n\n"
                f"Status: Ready to receive commands."
            )

    except Exception:
        if _ui:
            _ui.messageBox(f"Failed to start Antigravity Bridge:\n{traceback.format_exc()}")


def stop(context):
    """Called by Fusion 360 when the Add-In is stopped/unloaded."""
    global _app, _ui, _customEvent, _handlers, _httpd
    try:
        # Shutdown HTTP server
        if _httpd:
            _httpd.shutdown()
            _httpd.server_close()
            _httpd = None

        # Clean up event handlers
        if _customEvent:
            _customEvent.remove(_handlers[0])
            _app.unregisterCustomEvent(CUSTOM_EVENT_ID)
            _customEvent = None

        _handlers.clear()

        if _ui:
            _ui.messageBox("Antigravity Bridge has been stopped.")

    except Exception:
        if _ui:
            _ui.messageBox(f"Failed to stop Antigravity Bridge:\n{traceback.format_exc()}")
