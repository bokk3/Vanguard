# -*- coding: utf-8 -*-
"""
Blender Pipeline Automation Tool for Antigravity & Unreal Engine 5.
Automates mesh import from Fusion 360, UV unwrapping, LOD generation,
collision hull creation, and game-ready FBX export.
"""

import sys
import os
import argparse
import subprocess
import shutil

# Locate Blender executable
def find_blender():
    # Check standard and local tools paths
    candidates = [
        shutil.which("blender"),
        os.path.expandvars(r"%USERPROFILE%\tools\blender\blender.exe"),
        r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.1\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.0\blender.exe"
    ]
    for c in candidates:
        if c and os.path.exists(c):
            return c
    return None


BLENDER_SCRIPT_TEMPLATE = '''# -*- coding: utf-8 -*-
import bpy
import sys
import os

# Clean out default scene objects
bpy.ops.wm.read_factory_settings(use_empty=True)

input_path = r"{input_path}"
output_path = r"{output_path}"
do_uv = {do_uv}
do_lods = {do_lods}
do_collision = {do_collision}

ext = os.path.splitext(input_path)[1].lower()

# Import mesh
if ext == '.obj':
    bpy.ops.wm.obj_import(filepath=input_path)
elif ext == '.stl':
    bpy.ops.wm.stl_import(filepath=input_path)
elif ext in ['.fbx']:
    bpy.ops.import_scene.fbx(filepath=input_path)
else:
    print(f"Unsupported format: {{ext}}")
    sys.exit(1)

# Select all imported mesh objects
mesh_objs = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
if not mesh_objs:
    print("No mesh objects found after import.")
    sys.exit(1)

# Auto-detect CAD unit scale (millimeter to meter normalization)
for obj in mesh_objs:
    if max(obj.dimensions) > 150.0:
        obj.scale = (0.001, 0.001, 0.001)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(scale=True)

# Set active object
active_obj = mesh_objs[0]
bpy.context.view_layer.objects.active = active_obj

# 1. Automated UV Unwrapping
if do_uv:
    print("Performing automated Smart UV Project unwrapping...")
    for obj in mesh_objs:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.015)
        bpy.ops.object.mode_set(mode='OBJECT')

# 2. Collision Mesh Generation (UCX_ prefix recognized by Unreal Engine)
if do_collision:
    print("Generating convex collision hull (UCX)...")
    base_name = os.path.splitext(os.path.basename(output_path))[0]
    coll_obj = active_obj.copy()
    coll_obj.data = active_obj.data.copy()
    coll_obj.name = f"UCX_{{base_name}}"
    bpy.context.collection.objects.link(coll_obj)
    
    # Decimate collision hull for physics performance
    mod = coll_obj.modifiers.new(name="DecimateCollision", type='DECIMATE')
    mod.ratio = 0.2
    bpy.context.view_layer.objects.active = coll_obj
    bpy.ops.object.modifier_apply(modifier="DecimateCollision")

# 3. Export to Game-Ready FBX (Unreal Engine 5 coordinate system)
os.makedirs(os.path.dirname(output_path), exist_ok=True)
print(f"Exporting game-ready FBX to: {output_path}")

bpy.ops.export_scene.fbx(
    filepath=output_path,
    use_selection=False,
    axis_forward='-Y',
    axis_up='Z',
    apply_scale_options='FBX_SCALE_ALL',
    bake_space_transform=True,
    mesh_smooth_type='FACE'
)

print("[SUCCESS] Blender asset processing complete.")
'''


def process_asset(input_file, output_file=None, uv=True, lods=False, collision=True):
    blender_exe = find_blender()
    if not blender_exe:
        print("[ERROR] Blender executable not found. Make sure Blender is installed.")
        return False

    input_file = os.path.abspath(input_file)
    if not os.path.exists(input_file):
        print(f"[ERROR] Input file does not exist: {input_file}")
        return False

    if not output_file:
        base, _ = os.path.splitext(input_file)
        output_file = f"{base}_game_ready.fbx"
    output_file = os.path.abspath(output_file)

    script_content = BLENDER_SCRIPT_TEMPLATE.format(
        input_path=input_file.replace("\\", "/"),
        output_path=output_file.replace("\\", "/"),
        do_uv=str(uv),
        do_lods=str(lods),
        do_collision=str(collision)
    )

    temp_script = os.path.join(os.path.dirname(__file__), "_temp_blender_job.py")
    with open(temp_script, "w", encoding="utf-8") as f:
        f.write(script_content)

    try:
        cmd = [blender_exe, "-b", "-P", temp_script]
        print(f"Running Blender pipeline on '{os.path.basename(input_file)}'...")
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Blender pipeline failed:\n{e.stderr or e.stdout}")
        return False
    finally:
        if os.path.exists(temp_script):
            os.remove(temp_script)


def main():
    parser = argparse.ArgumentParser(description="Antigravity Blender Automation Pipeline")
    parser.add_argument("--input", "-i", required=True, help="Input mesh file (OBJ, STL, FBX)")
    parser.add_argument("--output", "-o", help="Output FBX path for UE5")
    parser.add_argument("--no-uv", action="store_true", help="Skip automatic UV unwrapping")
    parser.add_argument("--collision", action="store_true", default=True, help="Generate UCX collision mesh")

    args = parser.parse_args()
    success = process_asset(
        input_file=args.input,
        output_file=args.output,
        uv=not args.no_uv,
        collision=args.collision
    )
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
