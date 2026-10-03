# -*- coding: utf-8 -*-
"""
Olympus-4 Heavy Orbital Transport CAD Generator.
Builds the 68.0m x 36.0m x 16.0m Heavy Orbital Cargo Transport
featuring forward command cockpit, modular reinforced cargo bay pods,
twin heavy chemical-plasma engine blocks with exhaust bells,
and aerodynamic stabilizer strakes.
Polycount target: 12,000 - 32,000 triangles.
"""

import math
import bpy
import bmesh
from mathutils import Vector
from ..config import ASSET_CONFIGS
from ..polishing.materials import setup_asset_materials, get_or_create_material
from ..polishing.sockets import create_sockets
from ..polishing.collision import generate_collision_hulls
from ..polishing.hard_surface import apply_hard_surface_polishing


def build_transport_olympus4(config=None):
    """
    Generates the transport_olympus4 asset.
    """
    if config is None:
        config = ASSET_CONFIGS["transport_olympus4"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Main Fuselage Keel (Length 56.0m, Width 22.0m, Height 11.0m)
    # Forward is +Y (Y: -28 to +28)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 0.0, 1.5)
    )
    main_hull = bpy.context.active_object
    main_hull.name = "transport_olympus4"
    main_hull.scale = (22.0, 56.0, 11.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    root = main_hull

    setup_asset_materials(root, config["materials"])
    mat_hull = get_or_create_material("MI_Transport_Hull")
    mat_cargo = get_or_create_material("MI_Cargo_Bay")
    mat_engines = get_or_create_material("MI_Engine_Nozzles")
    mat_glow = get_or_create_material("MI_Engine_Superglow")
    mat_glass = get_or_create_material("MI_Cockpit_Glass")

    # 2. Forward Armored Nose & Cockpit Wedge (Y: +26 to +34m)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4,
        radius1=13.0,
        radius2=4.0,
        depth=12.0,
        location=(0.0, 30.0, 2.2),
        rotation=(math.radians(-90), 0, math.radians(45))
    )
    nose = bpy.context.active_object
    nose.name = "Transport_Nose_Visor"
    nose.scale = (1.10, 0.70, 1.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    nose.data.materials.append(mat_hull)
    nose.parent = root

    # Cockpit Windshield Visor (Y: +29m, Z: +5.2m)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 29.5, 5.0)
    )
    visor = bpy.context.active_object
    visor.name = "Transport_Cockpit_Canopy"
    visor.scale = (7.5, 3.5, 1.8)
    visor.rotation_euler = (math.radians(-25), 0, 0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    visor.data.materials.append(mat_glass)
    visor.parent = root

    # 3. Port & Starboard Modular Cargo Container Pods (Width out to 36.0m)
    # Cargo containers extend from X = ±11m to ±18m, Y = -16m to +16m
    for x_sign, side in [(-1, "L"), (1, "R")]:
        cx = x_sign * 14.5
        # Cargo Bay Frame
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(cx, 0.0, 1.5)
        )
        cargo_pod = bpy.context.active_object
        cargo_pod.name = f"Transport_CargoPod_{side}"
        cargo_pod.scale = (7.0, 34.0, 9.5)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        cargo_pod.data.materials.append(mat_cargo)
        cargo_pod.parent = root

        # Heavy Structural Outrigger Struts
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(x_sign * 17.5, 0.0, 1.5)
        )
        spar = bpy.context.active_object
        spar.name = f"Transport_Outrigger_{side}"
        spar.scale = (1.0, 36.0, 5.0)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        spar.data.materials.append(mat_hull)
        spar.parent = root

        # Outboard Winglets / Attitude Thruster Fins (Wingspan = 36m)
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(x_sign * 17.8, -12.0, 3.8)
        )
        winglet = bpy.context.active_object
        winglet.name = f"Transport_Winglet_{side}"
        winglet.scale = (0.4, 18.0, 4.5)
        winglet.rotation_euler = (0, math.radians(-x_sign * 15.0), 0)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        winglet.data.materials.append(mat_hull)
        winglet.parent = root

    # 4. Heavy Engine Mount Stern Assembly (Y: -28m to -34m)
    # Stern Engine Housing Block
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -28.0, 1.0)
    )
    engine_housing = bpy.context.active_object
    engine_housing.name = "Transport_Engine_Block"
    engine_housing.scale = (24.0, 10.0, 9.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    engine_housing.data.materials.append(mat_hull)
    engine_housing.parent = root

    # Twin Main Engine Rocket Bells (X = -8.5m and +8.5m, Y = -34.0m)
    for x_sign, side in [(-1, "L"), (1, "R")]:
        ex = x_sign * 8.5
        # Cylindrical Outer Engine Nacelle
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=24,
            radius=3.4,
            depth=8.0,
            location=(ex, -30.0, 1.0),
            rotation=(math.radians(90), 0, 0)
        )
        nacelle = bpy.context.active_object
        nacelle.name = f"Transport_EngineNacelle_{side}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        nacelle.data.materials.append(mat_engines)
        nacelle.parent = root

        # Flared Engine Bell Nozzle (Radius 3.2m at exit, Y = -34.0m)
        bpy.ops.mesh.primitive_cone_add(
            vertices=32,
            radius1=3.4,
            radius2=2.2,
            depth=4.5,
            location=(ex, -33.5, 1.0),
            rotation=(math.radians(-90), 0, 0)
        )
        nozzle = bpy.context.active_object
        nozzle.name = f"Transport_Nozzle_{side}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        nozzle.data.materials.append(mat_engines)
        nozzle.parent = root

        # Plasma Core Glow Disc inside nozzle
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=20,
            radius=2.1,
            depth=0.5,
            location=(ex, -33.2, 1.0),
            rotation=(math.radians(90), 0, 0)
        )
        glow_core = bpy.context.active_object
        glow_core.name = f"Transport_GlowCore_{side}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        glow_core.data.materials.append(mat_glow)
        glow_core.parent = root

    # 5. Dorsal Spine & Radiator Heatsink Bank
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -4.0, 7.8)
    )
    dorsal_spine = bpy.context.active_object
    dorsal_spine.name = "Transport_Dorsal_Spine"
    dorsal_spine.scale = (6.0, 42.0, 2.2)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    dorsal_spine.data.materials.append(mat_hull)
    dorsal_spine.parent = root

    # 6. Join All Structural Sub-Meshes into Watertight Solid Hull
    bpy.ops.object.select_all(action='DESELECT')
    children = [c for c in root.children if c.type == 'MESH']
    for c in children:
        c.select_set(True)
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.object.join()

    # Clean non-manifold / coincident vertices with remove_doubles
    bm = bmesh.new()
    bm.from_mesh(root.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.005)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)
    bm.to_mesh(root.data)
    bm.free()

    # Target Subsurf + Decimate for ~10,000 - 20,000 Tris
    cur_tris = sum(len(f.vertices) - 2 for f in root.data.polygons)
    if cur_tris < 8000:
        sub = root.modifiers.new(name="Subdiv", type='SUBSURF')
        sub.levels = 2
        bpy.ops.object.modifier_apply(modifier="Subdiv")
        post_tris = sum(len(f.vertices) - 2 for f in root.data.polygons)
        if post_tris > 22000:
            ratio = 20000.0 / post_tris
            dec = root.modifiers.new(name="Decimate_Target", type='DECIMATE')
            dec.ratio = ratio
            bpy.ops.object.modifier_apply(modifier="Decimate_Target")

    # Hard-surface Weighted Normals
    apply_hard_surface_polishing(root, bevel_width=0.04, bevel_segments=2, do_uv=True)

    # 7. Sockets & Collision Bounds
    create_sockets(root, config["sockets"])
    generate_collision_hulls(config["name"], root, config.get("collision_parts"))

    return root
