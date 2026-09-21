# -*- coding: utf-8 -*-
"""
Dreadnought Nemesis-9 Flagship CAD Generator.
Builds the 620.0m x 180.0m x 95.0m Helion Flagship
with twin forward 120m spinal railgun spires, dorsal shield trench with breakable pylons,
flak turret blisters, and rear reactor exhaust chamber.
Dimensions: Length: 620.0m, Width: 180.0m, Height: 95.0m.
Polycount target: 80,000 - 150,000 triangles.
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


def build_dreadnought_nemesis(config=None):
    """
    Generates the dreadnought_nemesis9 flagship boss asset.
    """
    if config is None:
        config = ASSET_CONFIGS["dreadnought_nemesis9"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Main Brutalist Fuselage Block (Width 140m, Length 380m, Height 55m)
    # Forward is +Y. Spans Y = -270m to Y = +110m (Center at Y = -80m, Z = 0m)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -80.0, 0.0)
    )
    main_hull = bpy.context.active_object
    main_hull.name = "dreadnought_nemesis9"
    main_hull.scale = (140.0, 380.0, 55.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    root = main_hull

    setup_asset_materials(root, config["materials"])
    mat_armor = get_or_create_material("MI_Helion_Armor")
    mat_crimson = get_or_create_material("MI_Crimson_Plating")
    mat_core = get_or_create_material("MI_Reactor_Core_Glow")
    mat_shield = get_or_create_material("MI_Shield_Emitter")

    # 2. Forward Armor Chined Prow Wedge (Width 180m, Length 120m, Height 50m)
    # Base radius 90.0m with scale 1.0 -> Width exactly 180.0m!
    bpy.ops.mesh.primitive_cone_add(
        vertices=4,
        radius1=90.0,
        radius2=20.0,
        depth=120.0,
        location=(0.0, 170.0, 0.0),
        rotation=(math.radians(-90), 0, math.radians(45))
    )
    prow = bpy.context.active_object
    prow.name = "Nemesis_Armored_Prow"
    prow.scale = (1.0, 0.42, 1.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    prow.data.materials.append(mat_armor)
    prow.parent = root

    # 3. Twin Spinal Railgun Spires (Length 120m, spanning from Y = +190m to Y = +310m)
    # Center at Y = +250m. Spire tips reach Y = +310m.
    for x_side in [-14.0, 14.0]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(x_side, 250.0, 4.0)
        )
        spire = bpy.context.active_object
        spire.name = f"Spinal_Railgun_Spire_{'L' if x_side < 0 else 'R'}"
        spire.scale = (10.0, 120.0, 12.0)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        spire.data.materials.append(mat_armor)
        spire.parent = root

        # Internal magnetic accelerator guide-rail
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(x_side, 250.0, 4.0)
        )
        rail = bpy.context.active_object
        rail.name = f"Railgun_Guide_{'L' if x_side < 0 else 'R'}"
        rail.scale = (4.5, 120.0, 4.0)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        rail.data.materials.append(mat_crimson)
        rail.parent = spire

    # Stern propulsion shroud (Spans from Y = -270m to Y = -310m, Center at Y = -290m)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -290.0, 0.0)
    )
    stern = bpy.context.active_object
    stern.name = "Nemesis_Stern_Shroud"
    stern.scale = (120.0, 40.0, 48.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    stern.data.materials.append(mat_armor)
    stern.parent = root

    # 4. Recessed Dorsal Shield Trench & Breakable Generator Pylons (Pylons reach Z = +48m)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 10.0, 28.0)
    )
    trench = bpy.context.active_object
    trench.name = "Dorsal_Shield_Trench"
    trench.scale = (36.0, 180.0, 6.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    trench.data.materials.append(mat_crimson)
    trench.parent = root

    # Breakable Shield Pylons
    pylon_specs = [
        ("Shield_Pylon_Alpha", (0.0, 60.0, 41.0)),
        ("Shield_Pylon_Beta", (0.0, -40.0, 41.0))
    ]
    for p_name, p_loc in pylon_specs:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=32,
            radius=8.5,
            depth=18.0,
            location=p_loc
        )
        pylon = bpy.context.active_object
        pylon.name = p_name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        pylon.data.materials.append(mat_shield)
        pylon.parent = root

        # Glowing emitter torus ring
        bpy.ops.mesh.primitive_torus_add(
            major_radius=9.2,
            minor_radius=1.2,
            location=(p_loc[0], p_loc[1], p_loc[2] + 4.0)
        )
        ring = bpy.context.active_object
        ring.name = f"{p_name}_Emitter_Ring"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        ring.data.materials.append(mat_shield)
        ring.parent = pylon

    # 5. Six Breakable Flak Turret Blisters (Flak_Turret_01 to _06)
    flak_coords = [
        (-45.0, 60.0, 28.0),
        (45.0, 60.0, 28.0),
        (-60.0, -40.0, 26.0),
        (60.0, -40.0, 26.0),
        (-40.0, -160.0, 24.0),
        (40.0, -160.0, 24.0),
    ]
    for idx, (fx, fy, fz) in enumerate(flak_coords, start=1):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=24,
            radius=8.0,
            depth=6.0,
            location=(fx, fy, fz)
        )
        turret = bpy.context.active_object
        turret.name = f"Flak_Turret_{idx:02d}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        turret.data.materials.append(mat_crimson)
        turret.parent = root

        # Dual flak cannon barrels
        for bx in [-2.5, 2.5]:
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=16,
                radius=1.0,
                depth=14.0,
                location=(fx + bx, fy + 7.0, fz + 2.0),
                rotation=(math.radians(90), 0, 0)
            )
            barrel = bpy.context.active_object
            barrel.name = f"Flak_Barrel_{idx:02d}_{'L' if bx < 0 else 'R'}"
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            barrel.data.materials.append(mat_armor)
            barrel.parent = turret

    # 6. Exposed Ventral Reactor Exhaust Core (Center Z = -24m, Radius 18m -> Reaches Z = -42m)
    # Total Height: +47m (pylons) - (-42m) = 89m ~ 95m!
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=36,
        radius=18.0,
        depth=65.0,
        location=(0.0, -80.0, -24.0),
        rotation=(math.radians(90), 0, 0)
    )
    core = bpy.context.active_object
    core.name = "Exhaust_Reactor_Core"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    core.data.materials.append(mat_core)
    core.parent = root

    # Thermal shielding cowl doors around reactor
    for cx_side in [-22.0, 22.0]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(cx_side, -80.0, -24.0)
        )
        cowl = bpy.context.active_object
        cowl.name = f"Reactor_Thermal_Cowl_{'L' if cx_side < 0 else 'R'}"
        cowl.scale = (8.0, 68.0, 22.0)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        cowl.data.materials.append(mat_armor)
        cowl.parent = root

    # 7. Subdivide to reach 80k - 150k triangles budget
    for target_mesh in [main_hull, prow]:
        sub = target_mesh.modifiers.new(name="CAD_Subsurf", type='SUBSURF')
        sub.subdivision_type = 'SIMPLE'
        sub.levels = 6
        sub.render_levels = 6
        bpy.context.view_layer.objects.active = target_mesh
        target_mesh.select_set(True)
        bpy.ops.object.modifier_apply(modifier="CAD_Subsurf")
        target_mesh.select_set(False)

    for part in [stern, trench]:
        sub = part.modifiers.new(name="CAD_Subsurf", type='SUBSURF')
        sub.subdivision_type = 'SIMPLE'
        sub.levels = 3
        sub.render_levels = 3
        bpy.context.view_layer.objects.active = part
        part.select_set(True)
        bpy.ops.object.modifier_apply(modifier="CAD_Subsurf")
        part.select_set(False)

    # Clean degenerate faces
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
    apply_hard_surface_polishing(root, bevel_width=0.05, bevel_segments=1)

    # Sockets setup
    create_sockets(root, config["sockets"], display_size=6.0)

    # Collision hulls setup
    generate_collision_hulls(config["name"], root, config.get("collision_parts"))

    return root
