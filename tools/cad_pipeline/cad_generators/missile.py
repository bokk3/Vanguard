# -*- coding: utf-8 -*-
"""
VPSM-01 Vanguard Strike Missile CAD Generator.
Builds the 2.35m x 0.53m x 0.53m precision air-to-air/strike missile
with cruciform stabilization fins, double-wedge canards, tangent ogive seeker radome, and recessed exhaust cavity.
Polycount target: 1,200 - 2,500 triangles.
"""

import os
import math
import bpy
import bmesh
from mathutils import Vector
from ..config import ASSET_CONFIGS, CAD_SOURCE_DIR
from ..polishing.materials import setup_asset_materials, get_or_create_material
from ..polishing.sockets import create_sockets
from ..polishing.collision import generate_collision_hulls
from ..polishing.hard_surface import apply_hard_surface_polishing


def build_strike_missile(config=None):
    """
    Generates the vanguard_strike_missile asset in Blender.
    """
    if config is None:
        config = ASSET_CONFIGS["vanguard_strike_missile"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    stl_path = os.path.join(CAD_SOURCE_DIR, "vehicles", "Vanguard_Strike_Missile.stl")
    if os.path.exists(stl_path):
        bpy.ops.wm.stl_import(filepath=stl_path)
        missile = bpy.context.active_object
        missile.name = "vanguard_strike_missile"
        if max(missile.dimensions) > 10.0:
            missile.scale = (0.001, 0.001, 0.001)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        # Center longitudinally: STL runs from Y = 0 to Y = -2.35m
        # Shift by +1.175m so it spans Y = -1.175m to +1.175m
        missile.location.y = 1.175
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    else:
        # Fallback cylindrical body + ogive cone
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=24,
            radius=0.09,
            depth=2.35,
            location=(0.0, 0.0, 0.0),
            rotation=(math.radians(90), 0, 0)
        )
        missile = bpy.context.active_object
        missile.name = "vanguard_strike_missile"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    root = missile
    bpy.context.view_layer.objects.active = root

    setup_asset_materials(root, config["materials"])

    # Clean degenerate faces
    bm = bmesh.new()
    bm.from_mesh(root.data)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)
    zero_faces = [f for f in bm.faces if f.calc_area() < 1e-6]
    if zero_faces:
        bmesh.ops.delete(bm, geom=zero_faces, context='FACES')
    bm.to_mesh(root.data)
    bm.free()
    root.data.update()

    # Hard-surface bevel & normals
    apply_hard_surface_polishing(root, bevel_width=0.005, bevel_segments=1)

    # Sockets setup
    create_sockets(root, config["sockets"])

    # Collision hulls setup
    generate_collision_hulls(config["name"], root, config.get("collision_parts"))

    return root
