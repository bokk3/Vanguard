# -*- coding: utf-8 -*-
"""
Cavern Trench Tunnel Segment CAD Generator.
Builds the 100.0m length modular cavern trench tunnel segment
with 35.0m wide x 28.0m high inner flight clearance, rocky cavern walls,
and industrial structural steel reinforcement ribs.
Polycount target: 6,000 - 12,000 triangles.
"""

import math
import random
import bpy
import bmesh
from mathutils import Vector
from ..config import ASSET_CONFIGS
from ..polishing.materials import setup_asset_materials, get_or_create_material
from ..polishing.sockets import create_sockets
from ..polishing.collision import generate_collision_hulls
from ..polishing.hard_surface import apply_hard_surface_polishing


def build_cavern_tunnel(config=None):
    """
    Generates the cavern_tunnel_straight asset.
    """
    if config is None:
        config = ASSET_CONFIGS["cavern_tunnel_straight"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Octagonal/Curved Hollow Rock Tunnel Shell (Length 100m, Width 45m, Height 38m)
    # Inner clearance: 35m wide x 28m high. Spans Y = -50m to +50m along longitudinal axis.
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32,
        radius=20.0,
        depth=100.0,
        location=(0.0, 0.0, 0.0),
        rotation=(math.radians(90), 0, 0),
        end_fill_type='NOTHING'
    )
    tunnel = bpy.context.active_object
    tunnel.name = "cavern_tunnel_straight"
    tunnel.scale = (1.12, 1.0, 0.95)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    root = tunnel

    # Invert face normals so the inside of the tunnel is rendered and lit
    bm = bmesh.new()
    bm.from_mesh(tunnel.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)

    # Subdivide length to add rocky displacement ribs
    random.seed(101)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=8)
    for v in bm.verts:
        # Avoid displacing the boundary rim vertices to maintain seamless snapping
        if abs(v.co.y) < 48.0:
            v.co.x += (random.random() - 0.5) * 2.8
            v.co.z += (random.random() - 0.5) * 2.4

    bm.to_mesh(tunnel.data)
    bm.free()
    tunnel.data.update()

    # Solidify the hollow shell so boundary rims are fully enclosed and 100% manifold
    mod_solid = tunnel.modifiers.new(name="Solidify", type='SOLIDIFY')
    mod_solid.thickness = 1.5
    mod_solid.offset = 1.0  # Expand outwards to preserve internal clearance
    bpy.context.view_layer.objects.active = tunnel
    bpy.ops.object.modifier_apply(modifier="Solidify")

    setup_asset_materials(root, config["materials"])
    mat_rock = get_or_create_material("MI_Cavern_Rock")
    mat_steel = get_or_create_material("MI_Cavern_Steel")

    # 2. Industrial Structural Steel Arch Ribs along interior (5 arches: Y = -40, -20, 0, +20, +40)
    for y_pos in [-40.0, -20.0, 0.0, 20.0, 40.0]:
        bpy.ops.mesh.primitive_torus_add(
            major_radius=19.4,
            minor_radius=0.90,
            major_segments=32,
            minor_segments=16,
            location=(0.0, y_pos, 0.0),
            rotation=(math.radians(90), 0, 0)
        )
        rib = bpy.context.active_object
        rib.name = f"Tunnel_Steel_Rib_{y_pos:+.0f}"
        rib.scale = (1.12, 1.0, 0.95)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        rib.data.materials.append(mat_steel)
        rib.parent = root

    # 3. Static Concave Trimesh Collision Wall (-colonly) for flight clearance
    col_obj = root.copy()
    col_obj.data = root.data.copy()
    col_obj.name = "cavern_tunnel_straight-colonly"
    bpy.context.collection.objects.link(col_obj)
    col_obj.display_type = 'WIRE'
    col_obj.parent = root

    create_sockets(root, config["sockets"], display_size=5.0)

    return root
