# -*- coding: utf-8 -*-
"""
Heavy Anti-Ship Torpedo CAD Generator.
Builds the 6.80m cylindrical torpedo with ogive warhead, 4 grid fins, and plasma thruster bell.
Dimensions: Length: 6.80m, Diameter: 1.10m, Fin Span: 2.20m.
Polycount target: 1,800 - 3,500 triangles.
"""

import math
import bpy
from mathutils import Vector
from ..config import ASSET_CONFIGS
from ..polishing.materials import setup_asset_materials, get_or_create_material
from ..polishing.sockets import create_sockets
from ..polishing.collision import generate_collision_hulls
from ..polishing.hard_surface import apply_hard_surface_polishing


def build_heavy_torpedo(config=None):
    """
    Generates the heavy_anti_ship_torpedo asset.
    """
    if config is None:
        config = ASSET_CONFIGS["heavy_anti_ship_torpedo"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Main Cylindrical Body (Diameter 1.10m -> Radius 0.55m, Length 4.60m)
    # Spans from Y = -2.90m to Y = +1.70m (Center at Y = -0.60m)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32,
        radius=0.55,
        depth=4.60,
        location=(0.0, -0.60, 0.0),
        rotation=(math.radians(90), 0, 0)
    )
    torpedo_body = bpy.context.active_object
    torpedo_body.name = "heavy_anti_ship_torpedo"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    root = torpedo_body

    setup_asset_materials(root, config["materials"])
    mat_hull = get_or_create_material("MI_Torpedo_Hull")
    mat_glow = get_or_create_material("MI_Warhead_Glow")
    mat_thrust = get_or_create_material("MI_Thrusters")

    # 2. Tangent Ogive Warhead Nose (Length 1.70m, Spans from Y = +1.70m to +3.40m, Center at Y = +2.55m)
    bpy.ops.mesh.primitive_cone_add(
        vertices=32,
        radius1=0.55,
        radius2=0.04,
        depth=1.70,
        location=(0.0, 2.55, 0.0),
        rotation=(math.radians(-90), 0, 0)
    )
    nose = bpy.context.active_object
    nose.name = "Torpedo_Ogive_Warhead"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    nose.data.materials.append(mat_glow)
    nose.parent = root

    # Warhead glowing ring grooves
    for y_offset in [1.90, 2.40]:
        r_major = 0.52 - (y_offset - 1.70) * 0.16
        bpy.ops.mesh.primitive_torus_add(
            major_radius=r_major,
            minor_radius=0.03,
            location=(0.0, y_offset, 0.0),
            rotation=(math.radians(90), 0, 0)
        )
        ring = bpy.context.active_object
        ring.name = f"Torpedo_Warhead_Ring_{y_offset:.2f}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        ring.data.materials.append(mat_glow)
        ring.parent = root

    # 3. Four Planar Grid Fins at Tail (Fin Span 2.20m tip-to-tip, Y = -2.40m)
    # Fin height = (2.20 - 1.10) / 2 = 0.55m. Center radius = 0.55 + 0.275 = 0.825m.
    fin_specs = [
        ("Fin_Starboard", (0.825, -2.40, 0.0), (0.55, 0.70, 0.04)),
        ("Fin_Port", (-0.825, -2.40, 0.0), (0.55, 0.70, 0.04)),
        ("Fin_Dorsal", (0.0, -2.40, 0.825), (0.04, 0.70, 0.55)),
        ("Fin_Ventral", (0.0, -2.40, -0.825), (0.04, 0.70, 0.55)),
    ]
    for fin_name, loc, sc in fin_specs:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=loc
        )
        fin = bpy.context.active_object
        fin.name = fin_name
        fin.scale = sc
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        fin.data.materials.append(mat_hull)
        fin.parent = root

    # 4. Plasma Thruster Bell at Stern (Spans from Y = -2.90m to -3.40m, Center at Y = -3.15m)
    bpy.ops.mesh.primitive_cone_add(
        vertices=32,
        radius1=0.42,
        radius2=0.52,
        depth=0.50,
        location=(0.0, -3.15, 0.0),
        rotation=(math.radians(90), 0, 0)
    )
    nozzle = bpy.context.active_object
    nozzle.name = "Torpedo_Thruster_Bell"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    nozzle.data.materials.append(mat_hull)
    nozzle.parent = root

    # Thruster emitter core (Y = -3.38m)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=24,
        radius=0.38,
        depth=0.15,
        location=(0.0, -3.38, 0.0),
        rotation=(math.radians(90), 0, 0)
    )
    plasma = bpy.context.active_object
    plasma.name = "Torpedo_Plasma_Core"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    plasma.data.materials.append(mat_thrust)
    plasma.parent = root

    # Hard-surface bevel & normals
    apply_hard_surface_polishing(root, bevel_width=0.012, bevel_segments=2)

    # Sockets setup
    create_sockets(root, config["sockets"])

    # Collision hulls setup
    generate_collision_hulls(config["name"], root, config.get("collision_parts"))

    return root
