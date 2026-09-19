# -*- coding: utf-8 -*-
"""
Unreal Engine 5 Remote Execution Client & Script Generator.
Enables Antigravity to communicate with a running Unreal Editor instance via Python Remote Execution,
or generate turnkey Python scripts for asset importing, Nanite configuration, and level assembly.
"""

import sys
import os
import json
import socket
import argparse
import time

UE_MULTICAST_GROUP = "239.0.0.1"
UE_MULTICAST_PORT = 6766
UE_DEFAULT_TCP_PORT = 6776


class UE5RemoteClient:
    def __init__(self, host="127.0.0.1", port=UE_DEFAULT_TCP_PORT, timeout=10.0):
        self.host = host
        self.port = port
        self.timeout = timeout

    def ping(self):
        """Check if Unreal Editor Python Remote Execution server is active."""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(2.0)
            s.connect((self.host, self.port))
            s.close()
            return True, f"Connected to Unreal Engine at {self.host}:{self.port}"
        except Exception as e:
            return False, f"Unreal Engine Remote Execution offline ({e}). Is UE5 running with Remote Execution enabled?"

    def execute_code(self, python_code: str):
        """Send Python code to Unreal Editor via Remote Execution socket."""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(self.timeout)
            s.connect((self.host, self.port))

            # UE5 Remote Execution JSON Protocol packet
            packet = {
                "version": 1,
                "magic": "ue_py",
                "type": "command",
                "command": python_code,
                "unattended": True
            }
            data_bytes = json.dumps(packet).encode('utf-8')
            s.sendall(data_bytes)

            response = s.recv(4096)
            s.close()
            if response:
                return json.loads(response.decode('utf-8'))
            return {"success": True, "output": "Command dispatched to Unreal Engine."}
        except Exception as e:
            return {"success": False, "error": f"Socket execution error: {e}"}

    def generate_import_script(self, fbx_path, destination_path="/Game/Environment", enable_nanite=True):
        """Generate a standalone Python script to import FBX and configure Nanite inside UE5."""
        fbx_path_clean = os.path.abspath(fbx_path).replace("\\", "/")
        asset_name = os.path.splitext(os.path.basename(fbx_path))[0]
        if not asset_name.startswith("SM_"):
            asset_name = f"SM_{asset_name}"

        script = f'''# -*- coding: utf-8 -*-
import unreal

fbx_file = "{fbx_path_clean}"
dest_path = "{destination_path}"
asset_name = "{asset_name}"

print(f"Importing {{fbx_file}} into {{dest_path}}/{{asset_name}}...")

# Configure FBX Import options
task = unreal.AssetImportTask()
task.filename = fbx_file
task.destination_path = dest_path
task.destination_name = asset_name
task.replace_existing = True
task.automated = True
task.save = True

options = unreal.FbxImportUI()
options.import_mesh = True
options.import_textures = False
options.import_materials = False
options.static_mesh_import_data.combine_meshes = True
options.static_mesh_import_data.auto_generate_collision = True
options.static_mesh_import_data.generate_lightmap_u_vs = True

task.options = options

# Execute Import
unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])

# Configure Nanite
asset_path = f"{{dest_path}}/{{asset_name}}.{{asset_name}}"
mesh = unreal.EditorAssetLibrary.load_asset(asset_path)

if mesh and isinstance(mesh, unreal.StaticMesh):
    nanite_settings = mesh.get_editor_property("nanite_settings")
    nanite_settings.set_editor_property("enabled", {enable_nanite})
    mesh.set_editor_property("nanite_settings", nanite_settings)
    unreal.EditorAssetLibrary.save_loaded_asset(mesh)
    print(f"[SUCCESS] Nanite enabled on {{asset_path}}")
else:
    print(f"[WARNING] Could not load imported static mesh at {{asset_path}}")
'''
        return script


def main():
    parser = argparse.ArgumentParser(description="Unreal Engine 5 Remote Execution Client")
    parser.add_argument("--ping", action="store_true", help="Ping UE5 Remote Execution server")
    parser.add_argument("--host", default="127.0.0.1", help="UE5 host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=UE_DEFAULT_TCP_PORT, help="UE5 port (default: 6776)")
    parser.add_argument("--eval", "-e", help="Evaluate Python code in running UE5 editor")
    parser.add_argument("--generate-import", help="Generate import script for given FBX path")
    parser.add_argument("--dest", default="/Game/Environment", help="Target destination path in UE5 project")
    parser.add_argument("--out-script", help="Save generated script to file")

    args = parser.parse_args()
    client = UE5RemoteClient(host=args.host, port=args.port)

    if args.ping:
        ok, msg = client.ping()
        print(msg)
        sys.exit(0 if ok else 1)

    if args.eval:
        res = client.execute_code(args.eval)
        print(json.dumps(res, indent=2))
        return

    if args.generate_import:
        code = client.generate_import_script(args.generate_import, destination_path=args.dest)
        if args.out_script:
            with open(args.out_script, "w", encoding="utf-8") as f:
                f.write(code)
            print(f"[SUCCESS] UE5 import script saved to: {args.out_script}")
        else:
            print(code)
        return

    parser.print_help()


if __name__ == "__main__":
    main()
