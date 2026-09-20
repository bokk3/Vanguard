# -*- coding: utf-8 -*-
"""
Automated Level-of-Detail (LOD) Generator.
Generates LOD0 (100%), LOD1 (50%), and LOD2 (25%) mesh variations using decimate modifiers.
"""

import bpy


def generate_lods(mesh_obj, ratios=(0.50, 0.25)):
    """
    Creates LOD1 and LOD2 copies of mesh_obj with applied decimation ratios.
    """
    if not mesh_obj or mesh_obj.type != 'MESH':
        return []

    lods = [mesh_obj]  # LOD0 is the original
    base_name = mesh_obj.name.replace("_LOD0", "")
    mesh_obj.name = f"{base_name}_LOD0"

    for idx, ratio in enumerate(ratios, start=1):
        lod_name = f"{base_name}_LOD{idx}"
        # Remove existing if any
        if lod_name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[lod_name], do_unlink=True)

        lod_obj = mesh_obj.copy()
        lod_obj.data = mesh_obj.data.copy()
        lod_obj.name = lod_name
        bpy.context.collection.objects.link(lod_obj)

        # Clear modifiers on LOD copy so decimate applies cleanly
        lod_obj.modifiers.clear()
        mod = lod_obj.modifiers.new(name=f"Decimate_LOD{idx}", type='DECIMATE')
        mod.ratio = ratio

        bpy.context.view_layer.objects.active = lod_obj
        bpy.ops.object.modifier_apply(modifier=mod.name)

        # Keep parent relationship if mesh_obj has a parent
        if mesh_obj.parent:
            lod_obj.parent = mesh_obj.parent

        # Hide LODs by default so they don't visually overlap
        lod_obj.hide_viewport = True
        lods.append(lod_obj)

    return lods
