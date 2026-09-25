# -*- coding: utf-8 -*-
"""
CAD-01: Capital Ship PBR Materials, Sockets & Collision Hulls
Headless Blender script -- run via:
  blender -b -P tools/cad_pipeline/cad01_capital_ships.py

Processes:
  1. carrier_soc_dauntless.glb  -- materials, sockets, -convcol hulls
  2. dreadnought_nemesis9.glb   -- breakable nodes, materials

Spec source: docs/ASSET_GENERATION_AND_MISSION_SPECIFICATION.md section 3.1C and 3.2B
"""

import bpy
import os
import sys

# --- Paths --------------------------------------------------------------------
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
VEHICLES_DIR = os.path.join(PROJECT_ROOT, "godot_project", "assets", "meshes", "vehicles")

CARRIER_IN  = os.path.join(VEHICLES_DIR, "carrier_soc_dauntless.glb")
CARRIER_OUT = os.path.join(VEHICLES_DIR, "carrier_soc_dauntless.glb")

DREAD_IN    = os.path.join(VEHICLES_DIR, "dreadnought_nemesis9.glb")
DREAD_OUT   = os.path.join(VEHICLES_DIR, "dreadnought_nemesis9.glb")


# --- Helpers ------------------------------------------------------------------

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path):
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.context.scene.objects if o.type == 'MESH']


def make_pbr_material(name, base_color, metallic=0.0, roughness=0.5,
                      emission_color=None, emission_strength=0.0,
                      alpha=1.0, transmission=0.0):
    """Create or retrieve a PBR material with the given parameters."""
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)
    bsdf.inputs['Base Color'].default_value = (*base_color, 1.0)
    bsdf.inputs['Metallic'].default_value   = metallic
    bsdf.inputs['Roughness'].default_value  = roughness
    bsdf.inputs['Alpha'].default_value      = alpha

    # Transmission -- Blender 4.x uses 'Transmission Weight', 3.x uses 'Transmission'
    for key in ('Transmission Weight', 'Transmission'):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = transmission
            break

    # Emission -- Blender 4.x splits colour from strength
    if emission_color and emission_strength > 0:
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value    = (*emission_color, 1.0)
            bsdf.inputs['Emission Strength'].default_value = emission_strength
        elif 'Emission' in bsdf.inputs:
            bsdf.inputs['Emission'].default_value          = (*emission_color, 1.0)
            bsdf.inputs['Emission Strength'].default_value = emission_strength

    out = nodes.new('ShaderNodeOutputMaterial')
    out.location = (300, 0)
    links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])

    if alpha < 1.0 or transmission > 0:
        mat.blend_method = 'BLEND'
    return mat


def assign_materials(mesh_obj, materials):
    """Replace all material slots on mesh_obj with the given list."""
    mesh_obj.data.materials.clear()
    for mat in materials:
        mesh_obj.data.materials.append(mat)


def add_socket_empty(name, location, parent_obj):
    """Add a Plain Axes Empty at world location, parented to parent_obj."""
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=location)
    empty = bpy.context.active_object
    empty.name = name
    empty.empty_display_size = 1.5
    empty.parent = parent_obj
    empty.matrix_parent_inverse = parent_obj.matrix_world.inverted()
    return empty


def make_convcol_from(source_obj, suffix, scale=(1, 1, 1), offset=(0, 0, 0)):
    """
    Duplicate source_obj, apply scale/offset, decimate heavily, run convex
    hull op, rename with -convcol suffix for Godot auto-collision import.
    """
    bpy.ops.object.select_all(action='DESELECT')
    source_obj.select_set(True)
    bpy.context.view_layer.objects.active = source_obj
    bpy.ops.object.duplicate(linked=False)
    hull = bpy.context.active_object
    hull.name = f"{source_obj.name}-convcol_{suffix}"
    hull.scale = scale
    hull.location = (
        source_obj.location.x + offset[0],
        source_obj.location.y + offset[1],
        source_obj.location.z + offset[2],
    )
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # Decimate to lean physics mesh
    mod = hull.modifiers.new("DecimateConvCol", 'DECIMATE')
    mod.ratio = 0.12
    bpy.context.view_layer.objects.active = hull
    bpy.ops.object.modifier_apply(modifier="DecimateConvCol")

    # Convex hull
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.convex_hull()
    bpy.ops.object.mode_set(mode='OBJECT')

    hull.hide_render = True  # collision-only, invisible in renders
    return hull


def export_glb(path):
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        export_materials='EXPORT',
        export_normals=True,
        export_texcoords=True,
        export_apply=True,
        export_extras=True,
    )
    print(f"[OK] Exported -> {path}")


# --- 1. SOC DAUNTLESS CARRIER -------------------------------------------------

def process_carrier():
    print("\n========== carrier_soc_dauntless.glb ==========")
    clear_scene()

    mesh_objs = import_glb(CARRIER_IN)
    if not mesh_objs:
        print("[ERROR] No mesh objects after import.")
        return False

    root = max(mesh_objs, key=lambda o: o.dimensions.length)
    print(f"  Root mesh: {root.name}  dims={tuple(round(d,1) for d in root.dimensions)}")

    # -- Materials (spec section 3.1C) ----------------------------------------
    mat_plating = make_pbr_material(
        "MI_Capital_Plating",
        base_color=(0.12, 0.14, 0.17),
        metallic=0.85, roughness=0.42,
    )
    mat_deck = make_pbr_material(
        "MI_Flight_Deck_Stripes",
        base_color=(0.18, 0.18, 0.18),
        metallic=0.10, roughness=0.78,
    )
    mat_glass = make_pbr_material(
        "MI_Bridge_Glass",
        base_color=(0.08, 0.55, 0.90),
        metallic=0.05, roughness=0.04,
        alpha=0.35, transmission=0.85,
    )
    mat_glow = make_pbr_material(
        "MI_Engine_Superglow",
        base_color=(0.05, 0.30, 1.00),
        metallic=0.0, roughness=0.1,
        emission_color=(0.15, 0.55, 1.0), emission_strength=18.0,
    )
    assign_materials(root, [mat_plating, mat_deck, mat_glass, mat_glow])
    print("  [OK] 4 material slots: MI_Capital_Plating, MI_Flight_Deck_Stripes, MI_Bridge_Glass, MI_Engine_Superglow")

    # -- Sockets (spec section 3.1C) ------------------------------------------
    for sock_name, loc in [
        ("SOCKET_Catapult_1",    (-25.0,  80.0, 12.0)),
        ("SOCKET_Catapult_2",    ( 25.0,  80.0, 12.0)),
        ("SOCKET_Bridge_Camera", ( 38.0, -40.0, 45.0)),
    ]:
        add_socket_empty(sock_name, loc, root)
        print(f"  [OK] Socket: {sock_name}")

    # -- Composite -convcol hulls (spec section 3.1C: Bow, Center_Deck, Island, Stern) --
    hull_zones = [
        # (zone suffix, scale,              y/z offset)
        ("Bow",         (0.85, 0.25, 0.70), (0,   120.0,   0)),
        ("Center_Deck", (1.00, 0.50, 0.80), (0,     0.0,   0)),
        ("Island",      (0.20, 0.15, 0.60), (38.0, -40.0, 20.0)),
        ("Stern",       (0.85, 0.25, 0.70), (0,  -120.0,   0)),
    ]
    for suffix, scale, offset in hull_zones:
        hull = make_convcol_from(root, suffix, scale=scale, offset=offset)
        print(f"  [OK] Collision hull: {hull.name}")

    export_glb(CARRIER_OUT)
    return True


# --- 2. DREADNOUGHT NEMESIS-9 -------------------------------------------------

def process_dreadnought():
    print("\n========== dreadnought_nemesis9.glb ==========")
    clear_scene()

    mesh_objs = import_glb(DREAD_IN)
    if not mesh_objs:
        print("[ERROR] No mesh objects after import.")
        return False

    root = max(mesh_objs, key=lambda o: o.dimensions.length)
    print(f"  Root mesh: {root.name}  dims={tuple(round(d,1) for d in root.dimensions)}")

    # -- Materials (TEAM_SYNC_HUB CAD-01) -------------------------------------
    mat_plating = make_pbr_material(
        "MI_Dreadnought_Plating",
        base_color=(0.06, 0.07, 0.08),
        metallic=0.92, roughness=0.55,
    )
    mat_shield = make_pbr_material(
        "MI_Shield_Emitter_Glow",
        base_color=(0.35, 0.00, 0.80),
        metallic=0.0, roughness=0.08,
        emission_color=(0.55, 0.10, 1.0), emission_strength=22.0,
    )
    mat_reactor = make_pbr_material(
        "MI_Reactor_Core",
        base_color=(1.00, 0.35, 0.05),
        metallic=0.0, roughness=0.05,
        emission_color=(1.0, 0.45, 0.05), emission_strength=35.0,
    )
    assign_materials(root, [mat_plating, mat_shield, mat_reactor])
    print("  [OK] 3 material slots: MI_Dreadnought_Plating, MI_Shield_Emitter_Glow, MI_Reactor_Core")

    # -- Shield Pylons (destroyable emitter towers) ----------------------------
    # Spec section 3.2B: Shield_Pylon_Alpha, Shield_Pylon_Beta (dorsal shield trench)
    for pylon_name, loc in [
        ("Shield_Pylon_Alpha", (  0.0,  80.0, 42.0)),
        ("Shield_Pylon_Beta",  (  0.0, -60.0, 42.0)),
    ]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
        pylon = bpy.context.active_object
        pylon.name = pylon_name
        pylon.scale = (8.0, 8.0, 20.0)
        bpy.ops.object.transform_apply(scale=True)
        pylon.data.materials.append(mat_shield)

        # Collision hull for the pylon
        bpy.ops.object.select_all(action='DESELECT')
        pylon.select_set(True)
        bpy.context.view_layer.objects.active = pylon
        bpy.ops.object.duplicate(linked=False)
        pylon_col = bpy.context.active_object
        pylon_col.name = f"{pylon_name}-convcol"
        pylon_col.hide_render = True
        print(f"  [OK] Breakable node: {pylon_name} + collision hull")

    # -- Flak Turrets (6 blisters, 3 port / 3 starboard) ----------------------
    # Spec section 3.2B: Flak_Turret_01 through Flak_Turret_06
    flak_locs = [
        (-55.0,  150.0, 20.0),   # Port forward
        (-70.0,    0.0, 15.0),   # Port midship
        (-55.0, -150.0, 18.0),   # Port aft
        ( 55.0,  150.0, 20.0),   # Starboard forward
        ( 70.0,    0.0, 15.0),   # Starboard midship
        ( 55.0, -150.0, 18.0),   # Starboard aft
    ]
    for i, loc in enumerate(flak_locs, start=1):
        bpy.ops.mesh.primitive_cylinder_add(radius=6.0, depth=8.0, location=loc)
        turret = bpy.context.active_object
        turret.name = f"Flak_Turret_{i:02d}"
        turret.data.materials.append(mat_plating)

        bpy.ops.object.select_all(action='DESELECT')
        turret.select_set(True)
        bpy.context.view_layer.objects.active = turret
        bpy.ops.object.duplicate(linked=False)
        turret_col = bpy.context.active_object
        turret_col.name = f"Flak_Turret_{i:02d}-convcol"
        turret_col.hide_render = True
        print(f"  [OK] Flak_Turret_{i:02d} + -convcol")

    export_glb(DREAD_OUT)
    return True


# --- Main ---------------------------------------------------------------------

if __name__ == "__main__":
    errors = []
    if not process_carrier():
        errors.append("carrier_soc_dauntless")
    if not process_dreadnought():
        errors.append("dreadnought_nemesis9")

    if errors:
        print(f"\n[FAILED] {', '.join(errors)}")
        sys.exit(1)
    else:
        print("\n[SUCCESS] CAD-01 complete.")
        sys.exit(0)
