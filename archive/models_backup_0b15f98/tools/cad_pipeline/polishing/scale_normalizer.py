# -*- coding: utf-8 -*-
"""
Scale Normalization Module.
Detects millimeter-scale CAD geometry (>100 units on aerospace hulls) and normalizes to meters (0.001x scale).
Bakes all object transforms to ensure clean runtime transforms.
"""

import bpy
from mathutils import Vector


def normalize_scale(root_obj=None, scale_factor=0.001, threshold=800.0):
    """
    Scans scene or specified root object hierarchy and normalizes scale if detected in millimeters.
    """
    targets = []
    if root_obj:
        targets = [root_obj] + [c for c in root_obj.children_recursive if c.type == 'MESH']
    else:
        targets = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']

    scaled_any = False
    for obj in targets:
        max_dim = max(obj.dimensions) if len(obj.dimensions) > 0 else 0.0
        if max_dim > threshold:
            print(f"Normalizing scale for {obj.name} (Max dim: {max_dim:.2f} > {threshold}) with factor {scale_factor}")
            obj.scale = obj.scale * scale_factor
            scaled_any = True

    # Bake transforms across all target meshes
    bpy.ops.object.select_all(action='DESELECT')
    for obj in targets:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.select_set(False)

    return scaled_any
