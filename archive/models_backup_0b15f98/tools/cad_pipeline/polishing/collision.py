# -*- coding: utf-8 -*-
"""
Collision Generation System.
Generates simplified convex collision hulls:
- Unreal Engine 5: UCX_<AssetName>_<Index>
- Godot 4: Meshes with suffix -convcol or -colonly
"""

import bpy
import bmesh
from mathutils import Vector


def generate_collision_hulls(asset_name, root_obj, collision_parts=None):
    """
    Generates convex collision hulls for the asset.
    If collision_parts is provided: [(part_name, center_loc, dimensions), ...],
    creates clean convex boxes.
    Otherwise, creates a decimated convex hull around root_obj.
    """
    created_hulls = []

    # Clean existing collision hulls
    to_delete = [
        obj for obj in bpy.context.scene.objects
        if obj.name.startswith(f"UCX_{asset_name}") or obj.name.endswith("-convcol") or obj.name.endswith("-colonly")
    ]
    for obj in to_delete:
        bpy.data.objects.remove(obj, do_unlink=True)

    if collision_parts:
        for idx, (part_name, loc, dims) in enumerate(collision_parts, start=1):
            bpy.ops.mesh.primitive_cube_add(location=loc)
            col_box = bpy.context.active_object
            col_box.name = f"UCX_{asset_name}_{part_name}_{idx:02d}"
            col_box.dimensions = Vector(dims)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            col_box.display_type = 'WIRE'
            if root_obj:
                col_box.parent = root_obj
            created_hulls.append(col_box)

            # Also create Godot -convcol representation if separate node is needed
            bpy.ops.mesh.primitive_cube_add(location=loc)
            g_col = bpy.context.active_object
            g_col.name = f"{asset_name}_{part_name}_{idx:02d}-convcol"
            g_col.dimensions = Vector(dims)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            g_col.display_type = 'WIRE'
            if root_obj:
                g_col.parent = root_obj
            created_hulls.append(g_col)
    else:
        # Generate bounding convex hull from root_obj
        if root_obj and root_obj.type == 'MESH':
            col_obj = root_obj.copy()
            col_obj.data = root_obj.data.copy()
            col_obj.name = f"UCX_{asset_name}_01"
            bpy.context.collection.objects.link(col_obj)

            # Apply convex hull
            bm = bmesh.new()
            bm.from_mesh(col_obj.data)
            bmesh.ops.convex_hull(bm, input=bm.verts)
            bm.to_mesh(col_obj.data)
            bm.free()
            col_obj.data.update()

            col_obj.display_type = 'WIRE'
            col_obj.parent = root_obj
            created_hulls.append(col_obj)

    return created_hulls
