# -*- coding: utf-8 -*-
"""
Hard-Surface Smoothing, Beveling, Weighted Normals, and UV Unwrapping.
Applies crisp CAD chamfer highlights without high-poly bloat,
custom split normals calculation, and Smart UV projection.
"""

import bpy
import bmesh
import math


def apply_hard_surface_polishing(mesh_obj, bevel_width=0.02, bevel_segments=2, do_uv=True):
    """
    Applies 3-stage bevel modifier, weighted normal modifier, and Smart UV projection.
    """
    if not mesh_obj or mesh_obj.type != 'MESH':
        return

    bpy.ops.object.select_all(action='DESELECT')
    mesh_obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_obj

    # 1. Ensure smooth shading across all polygons
    mesh = mesh_obj.data
    for p in mesh.polygons:
        p.use_smooth = True

    # 2. Add Bevel Modifier if not already present
    has_bevel = any(m.type == 'BEVEL' for m in mesh_obj.modifiers)
    if not has_bevel:
        bev = mesh_obj.modifiers.new(name="CAD_Bevel", type='BEVEL')
        bev.limit_method = 'ANGLE'
        bev.angle_limit = math.radians(35.0)
        bev.width = bevel_width
        bev.segments = bevel_segments
        bev.use_clamp_overlap = True
        bev.harden_normals = True

    # 3. Add Weighted Normal Modifier
    has_wn = any(m.type == 'WEIGHTED_NORMAL' for m in mesh_obj.modifiers)
    if not has_wn:
        wn = mesh_obj.modifiers.new(name="CAD_WeightedNormal", type='WEIGHTED_NORMAL')
        wn.weight = 50
        wn.keep_sharp = True

    # Try applying custom split normals data if supported
    try:
        bpy.ops.mesh.customdata_custom_splitnormals_add()
    except Exception:
        pass

    # 4. Smart UV Unwrapping
    if do_uv:
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
        bpy.ops.object.mode_set(mode='OBJECT')


def polish_all_meshes(root_obj=None, bevel_width=0.02, bevel_segments=2, do_uv=True):
    """
    Polishes all meshes in the scene or under root_obj.
    """
    targets = []
    if root_obj:
        targets = [c for c in root_obj.children_recursive if c.type == 'MESH']
        if root_obj.type == 'MESH':
            targets.append(root_obj)
    else:
        targets = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH' and not obj.name.startswith("UCX_") and not "-convcol" in obj.name]

    for obj in targets:
        apply_hard_surface_polishing(obj, bevel_width=bevel_width, bevel_segments=bevel_segments, do_uv=do_uv)
