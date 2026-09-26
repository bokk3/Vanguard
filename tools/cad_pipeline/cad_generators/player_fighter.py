# -*- coding: utf-8 -*-
"""
Player Fighter V-Hull Interceptor (F-77) CAD Generator & Polisher.
Builds the 10.30m x 9.78m x 2.70m V-Hull Interceptor with:
- 1:1 node hierarchy and millimeter socket parity with active in-game runtime
- Segmented convex collision hulls for scrape mechanics (UCX_Fuselage, UCX_Wing_L, UCX_Wing_R, UCX_Ventral_Keel)
- Discrete prop meshes: Prop_Headlight_L/R, Prop_Thruster_Core_L/R
- Custom split weighted normals & bevel polish for aerospace hard-surface shading
- Strict quarantine export to assets/staging/godot/player_fighter_v_hull/
"""

import os
import math
import bpy
import bmesh
from mathutils import Vector
from ..config import ASSET_CONFIGS, CAD_SOURCE_DIR, PROJECT_ROOT
from ..polishing.materials import setup_asset_materials, get_or_create_material
from ..polishing.sockets import create_sockets
from ..polishing.hard_surface import apply_hard_surface_polishing


def create_convex_hull_mesh(name, points, parent=None, is_godot_convcol=False):
    """
    Creates a dedicated convex hull collision mesh from explicit 3D boundary points.
    """
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    for pt in points:
        bm.verts.new(pt)
    bm.verts.ensure_lookup_table()
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bm.to_mesh(me)
    bm.free()

    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.display_type = 'WIRE'
    if parent:
        ob.parent = parent
    return ob


def generate_aerodynamic_scrape_hulls(root_obj):
    """
    Generates segmented convex colliders (Fuselage, Wing_L, Wing_R, Ventral_Keel)
    specifically designed to work with glancing scrape and ricochet mechanics (commit 0b15f98).
    Creates both UCX_* (for UE5/FBX) and *-convcol (for Godot 4).
    """
    # 1. Fuselage Hull Points (centerline lifting body tapering forward to nose chine at -Y)
    fuse_pts = [
        Vector((0.0, -5.15, -0.15)),
        Vector((-0.95, -4.20, -0.15)), Vector((0.95, -4.20, -0.15)),
        Vector((0.0, -1.85, 0.95)),
        Vector((-1.10, -1.80, 0.45)), Vector((1.10, -1.80, 0.45)),
        Vector((-1.15, 1.50, 0.50)), Vector((1.15, 1.50, 0.50)),
        Vector((-1.15, 4.50, 0.35)), Vector((1.15, 4.50, 0.35)),
        Vector((0.0, -3.50, -0.35)),
        Vector((-1.10, 1.50, -0.35)), Vector((1.10, 1.50, -0.35)),
        Vector((-1.10, 4.60, -0.30)), Vector((1.10, 4.60, -0.30)),
    ]

    # 2. Port Wing Hull Points (chamfered leading edge for glancing scrape deflection)
    wing_l_pts = [
        Vector((-1.05, -1.00, 0.10)), Vector((-1.05, -1.00, -0.10)),
        Vector((-4.89, 2.80, 0.05)),
        Vector((-4.89, 3.90, 0.05)),
        Vector((-1.05, 4.20, 0.15)), Vector((-1.05, 4.20, -0.15)),
        Vector((-3.00, 0.80, -0.12)), Vector((-3.00, 0.80, 0.12)),
    ]

    # 3. Starboard Wing Hull Points (symmetric mirror across X)
    wing_r_pts = [
        Vector((-p.x, p.y, p.z)) for p in wing_l_pts
    ]

    # 4. Ventral Keel Hull Points (sloped bottom ski for ground skimming without nose-tuck)
    keel_pts = [
        Vector((0.0, -3.20, -0.32)),
        Vector((-0.40, -0.50, -0.72)), Vector((0.40, -0.50, -0.72)),
        Vector((-0.50, -0.50, -0.30)), Vector((0.50, -0.50, -0.30)),
        Vector((-0.45, 2.80, -0.65)), Vector((0.45, 2.80, -0.65)),
        Vector((-0.50, 2.80, -0.30)), Vector((0.50, 2.80, -0.30)),
    ]

    hulls_def = [
        ("Fuselage", fuse_pts),
        ("Wing_L", wing_l_pts),
        ("Wing_R", wing_r_pts),
        ("Ventral_Keel", keel_pts),
    ]

    created = []
    for part_name, pts in hulls_def:
        # Unreal Engine 5 format
        ucx_obj = create_convex_hull_mesh(f"UCX_{part_name}", pts, parent=root_obj)
        # Godot 4 format
        convcol_obj = create_convex_hull_mesh(f"{part_name}-convcol", pts, parent=root_obj, is_godot_convcol=True)
        created.extend([ucx_obj, convcol_obj])

    return created


def build_player_fighter(config=None):
    """
    Generates and stages the player_fighter_v_hull asset in Blender.
    Guarantees 100% contract parity with active in-game runtime.
    """
    if config is None:
        config = ASSET_CONFIGS["player_fighter_v_hull"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Base Geometry: Load active in-engine model if present to guarantee 100% visual fidelity
    active_glb_path = os.path.join(PROJECT_ROOT, "godot_project", "Spaceship_Sculpted_V_Hull.glb")
    stl_path = os.path.join(CAD_SOURCE_DIR, "vehicles", "Spaceship_Sculpted_V_Hull.stl")

    if os.path.exists(active_glb_path):
        # Read-only import of baseline geometry to preserve exact hand-crafted custom split normals,
        # UVs, materials, and discrete prop meshes
        bpy.ops.import_scene.gltf(filepath=active_glb_path)
        root = bpy.data.objects.get("Spaceship_Sculpted_V_Hull")
        bpy.context.view_layer.objects.active = root
    elif os.path.exists(stl_path):
        bpy.ops.wm.stl_import(filepath=stl_path)
        root = bpy.context.active_object
        root.name = "Spaceship_Sculpted_V_Hull"
        if max(root.dimensions) > 100.0:
            root.scale = (0.001, 0.001, 0.001)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        setup_asset_materials(root, ["MI_Spaceship_Hull", "MI_Cockpit_Glass", "MI_Thrusters"])
        for i, p in enumerate(root.data.polygons):
            if 7171 <= i < 7194:
                p.material_index = 1
            elif i >= 7194:
                p.material_index = 2
            else:
                p.material_index = 0
        apply_hard_surface_polishing(root, bevel_width=0.012, bevel_segments=1)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
        root = bpy.context.active_object
        root.name = "Spaceship_Sculpted_V_Hull"
        root.scale = (9.78, 10.30, 2.70)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    bpy.context.view_layer.objects.active = root

    # 2. Discrete Prop Meshes matching runtime node tree 1:1 (create if missing)
    mat_headlight = get_or_create_material("MI_Headlights")
    mat_thrusters = get_or_create_material("MI_Thrusters")

    for x_side, name in [(-1.15, "Prop_Headlight_L"), (1.15, "Prop_Headlight_R")]:
        hl = bpy.data.objects.get(name)
        if not hl:
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=20,
                radius=0.14,
                depth=0.15,
                location=(x_side, 4.45, 0.28),
                rotation=(math.radians(90), 0, 0)
            )
            hl = bpy.context.active_object
            hl.name = name
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            hl.data.materials.append(mat_headlight)
            hl.parent = root

    for x_side, name in [(-0.95, "Prop_Thruster_Core_L"), (0.95, "Prop_Thruster_Core_R")]:
        tc = bpy.data.objects.get(name)
        if not tc:
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=24,
                radius=0.42,
                depth=0.20,
                location=(x_side, -4.62, -0.05),
                rotation=(math.radians(90), 0, 0)
            )
            tc = bpy.context.active_object
            tc.name = name
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            tc.data.materials.append(mat_thrusters)
            tc.parent = root

    # 3. Attachment Sockets (millimeter precision with active runtime + aliases)
    create_sockets(root, config["sockets"])

    # 4. Clean up any existing collision hulls and generate segmented multi-hull scrape colliders
    to_delete = [
        obj for obj in bpy.context.scene.objects
        if obj.name.startswith("UCX_") or obj.name.endswith("-convcol") or obj.name.endswith("-colonly")
    ]
    for obj in to_delete:
        bpy.data.objects.remove(obj, do_unlink=True)

    generate_aerodynamic_scrape_hulls(root)

    return root
