# -*- coding: utf-8 -*-
"""
Agility Mode 3D CAD Generators: Agility Gate Pylons & Target Practice Buoys.
Generates high-fidelity aerodynamic slalom waypoint pylons and target practice buoys
with 1:1 socket precision, hard-surface weighted normals, and PBR material slots.
"""

import math
import bpy
import bmesh
from mathutils import Vector
from ..config import ASSET_CONFIGS
from ..polishing.materials import setup_asset_materials, get_or_create_material
from ..polishing.sockets import create_sockets
from ..polishing.hard_surface import apply_hard_surface_polishing


def build_agility_gate_pylon(config=None):
    """
    Builds the 14.2m wide x 13.5m tall Agility Slalom Gate Pylon with:
    - Twin canted aerodynamic carbon-composite uprights
    - Heavy ground base pads
    - Upper arch bridge with holographic emitter nodes
    - Centered circular navigation ring (radius 6.0m)
    - Millimeter sockets: SOCKET_Gate_Center, SOCKET_Pylon_Top_L, SOCKET_Pylon_Top_R
    """
    if config is None:
        config = ASSET_CONFIGS["agility_gate_pylon"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Main Navigation Torus Ring (Radius 6.0m, Inner radius 5.6m)
    bpy.ops.mesh.primitive_torus_add(
        major_segments=48,
        minor_segments=16,
        major_radius=5.8,
        minor_radius=0.25,
        location=(0.0, 0.0, 6.0),
        rotation=(math.radians(90), 0, 0)
    )
    holo_ring = bpy.context.active_object
    holo_ring.name = "agility_gate_pylon"
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    root = holo_ring

    setup_asset_materials(root, config["materials"])
    mat_structure = get_or_create_material("MI_Gate_Structure")
    mat_ring = get_or_create_material("MI_Holo_Ring")
    mat_emitter = get_or_create_material("MI_Emitter_Node")

    holo_ring.data.materials.append(mat_ring)

    # 2. Port & Starboard Aerodynamic Upright Pylons
    for x_sign, side_name in [(-1, "L"), (1, "R")]:
        px = x_sign * 6.5
        # Upright Pillar (canted slightly inward)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, 0.0, 6.0))
        pylon = bpy.context.active_object
        pylon.name = f"Pylon_Upright_{side_name}"
        pylon.scale = (0.75, 1.40, 12.5)
        pylon.rotation_euler = (0, math.radians(-x_sign * 4.5), 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        pylon.data.materials.append(mat_structure)
        pylon.parent = root

        # Base Foot Pad
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x_sign * 7.0, 0.0, 0.35))
        foot = bpy.context.active_object
        foot.name = f"Pylon_Base_{side_name}"
        foot.scale = (2.2, 3.2, 0.70)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        foot.data.materials.append(mat_structure)
        foot.parent = root

        # Top Emitter Beacon
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=16,
            radius=0.35,
            depth=0.8,
            location=(x_sign * 6.0, 0.0, 12.6)
        )
        beacon = bpy.context.active_object
        beacon.name = f"Emitter_Beacon_{side_name}"
        beacon.data.materials.append(mat_emitter)
        beacon.parent = root

    # 3. Top Arch Crossbeam
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 12.5))
    arch = bpy.context.active_object
    arch.name = "Pylon_Arch_Crossbeam"
    arch.scale = (12.2, 1.10, 0.65)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    arch.data.materials.append(mat_structure)
    arch.parent = root

    # 4. Sockets
    create_sockets(root, config["sockets"])

    return root


def build_target_buoy_drone(config=None):
    """
    Builds the 3.6m x 3.6m x 3.2m Target Practice Sensor Buoy with:
    - Central pulsing target core sphere (diameter 1.8m)
    - Outer tri-fin stabilization gyro ring (span 3.6m)
    - 3 radial attitude thruster / sensor nodes at 120-degree intervals
    - Lower telemetry spike and antenna
    """
    if config is None:
        config = ASSET_CONFIGS["target_buoy_drone"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Central Core Sphere
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=32,
        ring_count=16,
        radius=0.90,
        location=(0.0, 0.0, 0.0)
    )
    core = bpy.context.active_object
    core.name = "target_buoy_drone"
    root = core

    setup_asset_materials(root, config["materials"])
    mat_core = get_or_create_material("MI_Target_Core")
    mat_armor = get_or_create_material("MI_Buoy_Armor")
    mat_ring = get_or_create_material("MI_Pulse_Ring")

    core.data.materials.append(mat_core)

    # 2. Outer Gyro Torus Ring
    bpy.ops.mesh.primitive_torus_add(
        major_segments=36,
        minor_segments=12,
        major_radius=1.75,
        minor_radius=0.15,
        location=(0.0, 0.0, 0.0),
        rotation=(math.radians(90), 0, 0)
    )
    ring = bpy.context.active_object
    ring.name = "Buoy_Gyro_Ring"
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    ring.data.materials.append(mat_ring)
    ring.parent = root

    # 3. 3 Radial Stabilizer Fins at 120-degree intervals
    for idx, deg in enumerate([0, 120, 240]):
        rad = math.radians(deg)
        fx = math.cos(rad) * 1.55
        fy = math.sin(rad) * 1.55
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(fx, fy, 0.0))
        fin = bpy.context.active_object
        fin.name = f"Stabilizer_Fin_{idx+1}"
        fin.scale = (0.75, 0.20, 0.95)
        fin.rotation_euler.z = rad
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        fin.data.materials.append(mat_armor)
        fin.parent = root

        # Sensor Node at tip
        sx = math.cos(rad) * 1.95
        sy = math.sin(rad) * 1.95
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=16,
            ring_count=8,
            radius=0.18,
            location=(sx, sy, 0.0)
        )
        node = bpy.context.active_object
        node.name = f"Sensor_Node_{idx+1}"
        node.data.materials.append(mat_core)
        node.parent = root

    # 4. Upper Dome Cap & Lower Antenna Spike
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=16,
        radius=0.55,
        depth=0.35,
        location=(0.0, 0.0, 0.85)
    )
    cap = bpy.context.active_object
    cap.name = "Armor_Cap_Top"
    cap.data.materials.append(mat_armor)
    cap.parent = root

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=0.08,
        depth=1.20,
        location=(0.0, 0.0, -1.10)
    )
    antenna = bpy.context.active_object
    antenna.name = "Ventral_Antenna"
    antenna.data.materials.append(mat_armor)
    antenna.parent = root

    # 5. Sockets
    create_sockets(root, config["sockets"])

    return root
