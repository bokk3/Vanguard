# -*- coding: utf-8 -*-
"""
Laser Sentry Turret CAD Generator.
Builds the 3.20m diameter x 2.40m height automated sentry turret
with hemispherical base plate, 2-axis gimbal, and dual liquid-cooled optical emitter tubes.
Dimensions: Base Diameter: 3.20m, Height: 2.40m, Length: ~3.30m.
Polycount target: 3,500 - 6,000 triangles.
"""

import math
import bpy
from mathutils import Vector
from ..config import ASSET_CONFIGS
from ..polishing.materials import setup_asset_materials, get_or_create_material
from ..polishing.sockets import create_sockets
from ..polishing.collision import generate_collision_hulls
from ..polishing.hard_surface import apply_hard_surface_polishing


def build_laser_sentry(config=None):
    """
    Generates the laser_sentry_turret asset.
    """
    if config is None:
        config = ASSET_CONFIGS["laser_sentry_turret"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Base Plate (Diameter 3.20m, Radius 1.60m, Height Z = 0.0 to 0.40m, Center at Z = 0.20m)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32,
        radius=1.60,
        depth=0.40,
        location=(0.0, 0.0, 0.20)
    )
    base_plate = bpy.context.active_object
    base_plate.name = "laser_sentry_turret"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    root = base_plate

    setup_asset_materials(root, config["materials"])
    mat_armor = get_or_create_material("MI_Turret_Armor")
    mat_optics = get_or_create_material("MI_Laser_Optics")
    mat_cool = get_or_create_material("MI_Coolant_Vents")

    # 4 Magnetic Anchor Prongs around perimeter
    for angle in [45, 135, 225, 315]:
        rad = math.radians(angle)
        px = math.cos(rad) * 1.50
        py = math.sin(rad) * 1.50
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(px, py, 0.15)
        )
        prong = bpy.context.active_object
        prong.name = f"Anchor_Prong_{angle}"
        prong.scale = (0.35, 0.35, 0.30)
        prong.rotation_euler.z = rad
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        prong.data.materials.append(mat_armor)
        prong.parent = root

    # 2. Yaw Gimbal Turret Ring (Node: Bone_Turret_Base) (Z = 0.40m to 0.70m, Center Z = 0.55m)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=28,
        radius=1.20,
        depth=0.30,
        location=(0.0, 0.0, 0.55)
    )
    yaw_ring = bpy.context.active_object
    yaw_ring.name = "Bone_Turret_Base"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    yaw_ring.data.materials.append(mat_armor)
    yaw_ring.parent = root

    # 3. Pitch Gimbal Housing (Node: Bone_Turret_Gimbal) (Center at Z = 1.30m)
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=24,
        ring_count=16,
        radius=0.85,
        location=(0.0, 0.15, 1.30)
    )
    gimbal_sphere = bpy.context.active_object
    gimbal_sphere.name = "Bone_Turret_Gimbal"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    gimbal_sphere.data.materials.append(mat_armor)
    gimbal_sphere.parent = yaw_ring

    # Targeting sensor optics bubble (Z = 2.05m to 2.35m -> Max height 2.35m)
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16,
        ring_count=12,
        radius=0.20,
        location=(0.0, 0.50, 2.05)
    )
    sensor = bpy.context.active_object
    sensor.name = "Turret_Targeting_Sensor"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    sensor.data.materials.append(mat_optics)
    sensor.parent = gimbal_sphere

    # 4. Dual Optical Laser Emitter Barrels (Left & Right at X = ±0.60m, Z = 1.40m)
    # Total length from back of base (Y = -1.60m) to emitter tip (Y = +1.70m) = 3.30m!
    for x_side in [-0.60, 0.60]:
        # Outer barrel jacket (Length 1.40m, Spans Y = +0.20m to +1.60m, Center Y = +0.90m)
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=20,
            radius=0.18,
            depth=1.40,
            location=(x_side, 0.90, 1.40),
            rotation=(math.radians(90), 0, 0)
        )
        jacket = bpy.context.active_object
        jacket.name = f"Barrel_Jacket_{'L' if x_side < 0 else 'R'}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        jacket.data.materials.append(mat_armor)
        jacket.parent = gimbal_sphere

        # Liquid cooling sleeves
        for y_slv in [0.45, 0.85, 1.25]:
            bpy.ops.mesh.primitive_torus_add(
                major_radius=0.22,
                minor_radius=0.03,
                major_segments=16,
                minor_segments=8,
                location=(x_side, y_slv, 1.40),
                rotation=(math.radians(90), 0, 0)
            )
            sleeve = bpy.context.active_object
            sleeve.name = f"Cooling_Sleeve_{'L' if x_side < 0 else 'R'}_{y_slv:.2f}"
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            sleeve.data.materials.append(mat_cool)
            sleeve.parent = jacket

        # Optical lens emitter tip (at Y = +1.65m)
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=16,
            ring_count=12,
            radius=0.15,
            location=(x_side, 1.65, 1.40)
        )
        lens = bpy.context.active_object
        lens.name = f"Emitter_Lens_{'L' if x_side < 0 else 'R'}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        lens.data.materials.append(mat_optics)
        lens.parent = jacket

    # Hard-surface bevel & normals
    apply_hard_surface_polishing(root, bevel_width=0.015, bevel_segments=1)

    # Sockets setup
    create_sockets(root, config["sockets"])

    # Collision hulls setup
    generate_collision_hulls(config["name"], root, config.get("collision_parts"))

    return root
