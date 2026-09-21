# -*- coding: utf-8 -*-
"""
SOC Dauntless Fleet Super-Carrier CAD Generator.
Builds the 480.0m x 135.0m x 72.0m Fleet Super-Carrier
with dual angled flight deck grooves, starboard command island, 6 engine bells, and point-defense blisters.
Dimensions: Length: 480.0m, Width: 135.0m, Height: 72.0m.
Polycount target: 65,000 - 120,000 triangles.
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


def build_carrier_dauntless(config=None):
    """
    Generates the carrier_soc_dauntless capital ship asset.
    """
    if config is None:
        config = ASSET_CONFIGS["carrier_soc_dauntless"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Main Keel & Superstructure Block (Length 400m, Width 95m, Height 44m)
    # Forward is +Y. Spans Y = -220m to Y = +180m, Center at Y = -20m.
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -20.0, -4.0)
    )
    main_hull = bpy.context.active_object
    main_hull.name = "carrier_soc_dauntless"
    main_hull.scale = (95.0, 400.0, 44.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    root = main_hull

    setup_asset_materials(root, config["materials"])
    mat_plate = get_or_create_material("MI_Capital_Plating")
    mat_deck = get_or_create_material("MI_Flight_Deck_Stripes")
    mat_bridge = get_or_create_material("MI_Bridge_Glass")
    mat_glow = get_or_create_material("MI_Engine_Superglow")

    # 2. Armored Bow Ram Prow (Length 80m, extending from Y = +160m to +240m)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4,
        radius1=55.0,
        radius2=15.0,
        depth=80.0,
        location=(0.0, 200.0, -4.0),
        rotation=(math.radians(-90), 0, math.radians(45))
    )
    bow = bpy.context.active_object
    bow.name = "Carrier_Bow_Prow"
    bow.scale = (0.95, 0.40, 1.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bow.data.materials.append(mat_plate)
    bow.parent = root

    # 3. Dual Angled Flight Decks (Span 135m, Length 360m, Z = +16m)
    # Spans from Y = -200m to +160m. Center at Y = -20m.
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -20.0, 16.0)
    )
    flight_deck = bpy.context.active_object
    flight_deck.name = "Carrier_Flight_Deck"
    flight_deck.scale = (135.0, 360.0, 4.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    flight_deck.data.materials.append(mat_deck)
    flight_deck.parent = root

    # High-density catapult rail grooves (Port and Starboard at X = -25m and +25m)
    for cx in [-25.0, 25.0]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(cx, 80.0, 18.2)
        )
        groove = bpy.context.active_object
        groove.name = f"Catapult_Groove_{'L' if cx < 0 else 'R'}"
        groove.scale = (5.0, 150.0, 0.6)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        groove.data.materials.append(mat_deck)
        groove.parent = flight_deck

    # 4. Starboard Command Island (X = +42m, Y = -40m, Height to Z = +54m)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(42.0, -40.0, 32.0)
    )
    island = bpy.context.active_object
    island.name = "Carrier_Command_Island"
    island.scale = (26.0, 70.0, 28.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    island.data.materials.append(mat_plate)
    island.parent = root

    # Panoramic Command Bridge Observation Deck (Z = +45m)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(42.0, -20.0, 45.0)
    )
    bridge_glass = bpy.context.active_object
    bridge_glass.name = "Carrier_Bridge_Glass"
    bridge_glass.scale = (22.0, 16.0, 5.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bridge_glass.data.materials.append(mat_bridge)
    bridge_glass.parent = island

    # High-Gain Sensor Radome on Island Roof (Top reaches Z = +47m)
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=32,
        ring_count=20,
        radius=7.0,
        location=(42.0, -45.0, 40.0)
    )
    radome = bpy.context.active_object
    radome.name = "Carrier_Sensor_Radome"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    radome.data.materials.append(mat_plate)
    radome.parent = island

    # 5. Six Clustered Fusion Engine Exhaust Bells at Stern (Extends back to Y = -240m)
    engine_coords = [
        (-25.0, -227.0, 8.0),
        (0.0, -227.0, 8.0),
        (25.0, -227.0, 8.0),
        (-25.0, -227.0, -8.0),
        (0.0, -227.0, -8.0),
        (25.0, -227.0, -8.0),
    ]
    for idx, (ex, ey, ez) in enumerate(engine_coords, start=1):
        # Outer nozzle bell (depth 26m, reaches Y = -240m)
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=48,
            radius=8.5,
            depth=26.0,
            location=(ex, ey, ez),
            rotation=(math.radians(90), 0, 0)
        )
        bell = bpy.context.active_object
        bell.name = f"Carrier_Engine_Bell_{idx:02d}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        bell.data.materials.append(mat_plate)
        bell.parent = root

        # Internal glowing fusion emitter core
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=36,
            radius=7.2,
            depth=2.0,
            location=(ex, ey - 12.0, ez),
            rotation=(math.radians(90), 0, 0)
        )
        plume = bpy.context.active_object
        plume.name = f"Carrier_Engine_Plume_{idx:02d}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        plume.data.materials.append(mat_glow)
        plume.parent = bell

    # 6. Six Point-Defense Turret Sponsons / Blisters
    turret_blister_locs = [
        (-45.0, 120.0, 10.0),
        (45.0, 120.0, 10.0),
        (-50.0, -60.0, 14.0),
        (50.0, -60.0, 14.0),
        (-30.0, -180.0, 12.0),
        (30.0, -180.0, 12.0),
    ]
    for idx, (bx, by, bz) in enumerate(turret_blister_locs, start=1):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=32,
            radius=6.0,
            depth=4.5,
            location=(bx, by, bz)
        )
        blister = bpy.context.active_object
        blister.name = f"Defense_Blister_{idx:02d}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        blister.data.materials.append(mat_plate)
        blister.parent = root

    # 7. Ventral Docking Bay Chamber (Z reaches -25m -> Total height 47 - (-25) = 72.0m)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -40.0, -21.0)
    )
    dock = bpy.context.active_object
    dock.name = "Carrier_Ventral_Docking_Bay"
    dock.scale = (45.0, 120.0, 8.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    dock.data.materials.append(mat_plate)
    dock.parent = root

    # 8. Detailed Armor Plating Grid on Main Hull & Flight Deck to reach 65k - 120k budget
    for target_mesh in [main_hull, flight_deck]:
        sub = target_mesh.modifiers.new(name="CAD_Subsurf", type='SUBSURF')
        sub.subdivision_type = 'SIMPLE'
        sub.levels = 6
        sub.render_levels = 6
        bpy.context.view_layer.objects.active = target_mesh
        target_mesh.select_set(True)
        bpy.ops.object.modifier_apply(modifier="CAD_Subsurf")
        target_mesh.select_set(False)

    # Subdivide bow and island moderately
    for part in [bow, island]:
        sub = part.modifiers.new(name="CAD_Subsurf", type='SUBSURF')
        sub.subdivision_type = 'SIMPLE'
        sub.levels = 3
        sub.render_levels = 3
        bpy.context.view_layer.objects.active = part
        part.select_set(True)
        bpy.ops.object.modifier_apply(modifier="CAD_Subsurf")
        part.select_set(False)

    # Clean any degenerate faces across all meshes
    for obj in [root] + list(root.children_recursive):
        if obj.type == 'MESH':
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)
            zero_faces = [f for f in bm.faces if f.calc_area() < 1e-6]
            if zero_faces:
                bmesh.ops.delete(bm, geom=zero_faces, context='FACES')
            bm.to_mesh(obj.data)
            bm.free()
            obj.data.update()

    # Hard-surface bevel & normals
    apply_hard_surface_polishing(root, bevel_width=0.04, bevel_segments=1)

    # Sockets setup
    create_sockets(root, config["sockets"], display_size=5.0)

    # Collision hulls setup
    generate_collision_hulls(config["name"], root, config.get("collision_parts"))

    return root
