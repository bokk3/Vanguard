# -*- coding: utf-8 -*-
"""
Multi-Engine Asset Exporter.
Handles automated export to:
- Godot 4: glTF 2.0 (.glb) with meters unit scale (-Z Forward, +Y Up).
- Unreal Engine 5: Autodesk FBX (.fbx) with centimeters unit scale (+X Forward, +Z Up).
"""

import os
import shutil
import bpy


def export_godot_glb(output_path, legacy_copy_path=None):
    """
    Exports the current Blender scene to a Godot-ready glTF 2.0 binary (.glb).
    """
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)

    # Ensure export includes custom properties, materials, and empties (sockets)
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format='GLB',
        export_apply=False,
        export_yup=True,
        export_materials='EXPORT',
        export_extras=True,
    )
    print(f"[EXPORT] Godot GLB exported successfully to: {output_path}")

    if legacy_copy_path:
        os.makedirs(os.path.dirname(os.path.abspath(legacy_copy_path)), exist_ok=True)
        shutil.copy2(output_path, legacy_copy_path)
        print(f"[EXPORT] Legacy copy updated at: {legacy_copy_path}")

    return output_path


def export_unreal_fbx(output_path):
    """
    Exports the current Blender scene to an Unreal Engine 5 ready Autodesk FBX (.fbx).
    Enforces +X Forward, +Z Up, centimeter scaling, and baked transforms.
    """
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)

    bpy.ops.export_scene.fbx(
        filepath=output_path,
        use_selection=False,
        axis_forward='X',
        axis_up='Z',
        apply_scale_options='FBX_SCALE_ALL',
        bake_space_transform=True,
        mesh_smooth_type='FACE',
        add_leaf_bones=False,
    )
    print(f"[EXPORT] Unreal Engine FBX exported successfully to: {output_path}")
    return output_path


def export_asset(asset_config, export_format='all'):
    """
    Exports asset according to its config in export_format ('glb', 'fbx', 'all').
    """
    paths = asset_config.get("export_paths", {})
    exported = {}

    if export_format in ['glb', 'all'] and "godot_glb" in paths:
        glb_path = paths["godot_glb"]
        legacy_path = paths.get("godot_legacy_glb")
        exported["glb"] = export_godot_glb(glb_path, legacy_path)

    if export_format in ['fbx', 'all'] and "ue5_fbx" in paths:
        fbx_path = paths["ue5_fbx"]
        exported["fbx"] = export_unreal_fbx(fbx_path)

    return exported
