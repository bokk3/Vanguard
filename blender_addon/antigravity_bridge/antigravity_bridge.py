# -*- coding: utf-8 -*-
"""
Antigravity Live Bridge for Blender 4.2+
Runs an HTTP server on port 9877 inside Blender.
Enables real-time remote control, code execution on Blender's main thread,
and automated asset staging between Antigravity, Fusion 360, and Unreal Engine.
"""

import sys
import os
import io
import json
import queue
import threading
import traceback
from http.server import HTTPServer, BaseHTTPRequestHandler

import bpy

BRIDGE_PORT = 9877
task_queue = queue.Queue()
server_instance = None
server_thread = None


def main_thread_dispatcher():
    """Timer callback running on Blender's main thread every 50ms."""
    while not task_queue.empty():
        try:
            task = task_queue.get_nowait()
        except queue.Empty:
            break

        code = task.get("code", "")
        result_holder = task["result"]
        event = task["event"]

        old_stdout = sys.stdout
        old_stderr = sys.stderr
        buf = io.StringIO()
        sys.stdout = buf
        sys.stderr = buf

        try:
            exec_globals = {
                "bpy": bpy,
                "os": os,
                "sys": sys,
                "math": __import__("math"),
                "mathutils": __import__("mathutils") if "mathutils" in sys.modules or True else None,
                "__name__": "__main__"
            }
            exec(code, exec_globals)
            result_holder["success"] = True
            result_holder["output"] = buf.getvalue()
            result_holder["error"] = None
        except Exception as e:
            result_holder["success"] = False
            result_holder["output"] = buf.getvalue()
            result_holder["error"] = traceback.format_exc()
        finally:
            sys.stdout = old_stdout
            sys.stderr = old_stderr
            event.set()

    return 0.05  # Re-run timer in 50ms


class BlenderBridgeHTTPHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Silence default HTTP server logging to avoid console spam
        pass

    def _set_headers(self, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(200)

    def do_GET(self):
        if self.path == "/ping":
            data = {
                "status": "online",
                "bridge": "Antigravity Blender Bridge",
                "version": "1.0.0",
                "blender_version": bpy.app.version_string,
                "active_file": bpy.data.filepath or "Untitled.blend",
                "objects_count": len(bpy.data.objects)
            }
            self._set_headers(200)
            self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Not Found"}).encode("utf-8"))

    def do_POST(self):
        if self.path == "/execute":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length).decode("utf-8")
            try:
                payload = json.loads(body)
                code_to_exec = payload.get("code", "")
            except Exception as e:
                self._set_headers(400)
                self.wfile.write(json.dumps({"success": False, "error": f"Invalid JSON: {e}"}).encode("utf-8"))
                return

            event = threading.Event()
            result_holder = {}
            task_queue.put({"code": code_to_exec, "result": result_holder, "event": event})

            # Wait up to 60s for main thread to execute
            completed = event.wait(timeout=60.0)
            if not completed:
                self._set_headers(504)
                self.wfile.write(json.dumps({"success": False, "error": "Execution timed out"}).encode("utf-8"))
                return

            self._set_headers(200)
            self.wfile.write(json.dumps(result_holder).encode("utf-8"))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Not Found"}).encode("utf-8"))


def start_server():
    global server_instance, server_thread
    if server_instance:
        print("[Antigravity] Bridge server is already running.")
        return

    try:
        server_instance = HTTPServer(("127.0.0.1", BRIDGE_PORT), BlenderBridgeHTTPHandler)
        server_thread = threading.Thread(target=server_instance.serve_forever, daemon=True)
        server_thread.start()
        print(f"[Antigravity] Blender Live Bridge listening on http://127.0.0.1:{BRIDGE_PORT}")
    except Exception as e:
        print(f"[Antigravity ERROR] Failed to start bridge server: {e}")


# =========================================================================
# BLENDER UI PANEL (3D VIEWPORT SIDEBAR -> 'Antigravity' TAB)
# =========================================================================

class ANTIGRAVITY_PT_BridgePanel(bpy.types.Panel):
    bl_label = "Antigravity Bridge"
    bl_idname = "ANTIGRAVITY_PT_bridge_panel"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Antigravity"

    def draw(self, context):
        layout = self.layout
        col = layout.column(align=True)
        box = col.box()
        box.label(text="🟢 Bridge: ONLINE", icon="RADIOBUT_ON")
        box.label(text=f"Port: {BRIDGE_PORT} (http://127.0.0.1:{BRIDGE_PORT})")
        
        col.separator()
        col.operator("antigravity.import_sculpted_spaceship", text="Import Sculpted Spaceship", icon="MESH_MONKEY")
        col.operator("antigravity.smart_uv_all", text="Auto Smart UV Unwarp All", icon="UV")


class ANTIGRAVITY_OT_ImportSpaceship(bpy.types.Operator):
    bl_idname = "antigravity.import_sculpted_spaceship"
    bl_label = "Import Sculpted Spaceship"
    bl_description = "Import the latest Sculpted Spaceship from the Exports folder"

    def execute(self, context):
        exports_dir = r"c:\Users\Boris\Documents\antigravity\lucid-davinci\Exports"
        fbx_path = os.path.join(exports_dir, "Spaceship_Sculpted_V_Hull.fbx")
        stl_path = os.path.join(exports_dir, "Spaceship_Sculpted_V_Hull.stl")

        target = fbx_path if os.path.exists(fbx_path) else stl_path
        if not os.path.exists(target):
            self.report({"ERROR"}, f"Asset not found: {target}")
            return {"CANCELLED"}

        if target.endswith(".fbx"):
            bpy.ops.import_scene.fbx(filepath=target)
        else:
            bpy.ops.wm.stl_import(filepath=target)

        self.report({"INFO"}, f"Imported: {os.path.basename(target)}")
        return {"FINISHED"}


class ANTIGRAVITY_OT_SmartUVAll(bpy.types.Operator):
    bl_idname = "antigravity.smart_uv_all"
    bl_label = "Auto Smart UV Unwrap All"
    bl_description = "Run Smart UV Project on all selected mesh objects"

    def execute(self, context):
        selected_meshes = [obj for obj in context.selected_objects if obj.type == "MESH"]
        if not selected_meshes:
            self.report({"WARNING"}, "No mesh objects selected.")
            return {"CANCELLED"}

        count = 0
        for obj in selected_meshes:
            context.view_layer.objects.active = obj
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.uv.smart_project(angle_limit=1.15192, island_margin=0.02)
            bpy.ops.object.mode_set(mode="OBJECT")
            count += 1

        self.report({"INFO"}, f"Smart UV unwrap applied to {count} mesh(es).")
        return {"FINISHED"}


classes = (
    ANTIGRAVITY_PT_BridgePanel,
    ANTIGRAVITY_OT_ImportSpaceship,
    ANTIGRAVITY_OT_SmartUVAll,
)


_is_registered = False

def register():
    global _is_registered
    if _is_registered:
        return
    _is_registered = True

    for cls in classes:
        try:
            bpy.utils.register_class(cls)
        except Exception:
            pass

    if not bpy.app.timers.is_registered(main_thread_dispatcher):
        bpy.app.timers.register(main_thread_dispatcher, persistent=True)

    start_server()


def unregister():
    global _is_registered
    _is_registered = False
    for cls in reversed(classes):
        try:
            bpy.utils.unregister_class(cls)
        except Exception:
            pass

    if bpy.app.timers.is_registered(main_thread_dispatcher):
        bpy.app.timers.unregister(main_thread_dispatcher)


register()
