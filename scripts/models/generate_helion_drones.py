# -*- coding: utf-8 -*-
"""
Helion Combat Drone Fleet Generator for Project Vanguard (Blender 4.2+).
Builds three bespoke adversary UCAV (Unmanned Combat Air Vehicle) models:
1. "Stalker-4" Tactical Recon Drone (drone_stalker4_recon.glb)
2. "Razor" High-Speed Skirmisher Interceptor (drone_razor_skirmisher.glb)
3. "Strikefly" Heavy Dive Bomber Drone (drone_strikefly_bomber.glb)
Exports game-ready GLBs directly to godot_project/assets/meshes/vehicles/.
"""

import bpy
import bmesh
import math
import os
import sys

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_pbr_materials():
    """Creates standardized PBR materials for the Helion adversary fleet."""
    # 1. Dark Stealth Nano-composite Hull
    mat_hull = bpy.data.materials.new("Mat_HelionHull")
    mat_hull.use_nodes = True
    bsdf_h = mat_hull.node_tree.nodes.get("Principled BSDF")
    if bsdf_h:
        bsdf_h.inputs['Base Color'].default_value = (0.12, 0.14, 0.17, 1.0)
        bsdf_h.inputs['Metallic'].default_value = 0.85
        bsdf_h.inputs['Roughness'].default_value = 0.28
        
    # 2. Crimson Armor Plates / Trim
    mat_trim = bpy.data.materials.new("Mat_HelionCrimson")
    mat_trim.use_nodes = True
    bsdf_t = mat_trim.node_tree.nodes.get("Principled BSDF")
    if bsdf_t:
        bsdf_t.inputs['Base Color'].default_value = (0.85, 0.08, 0.12, 1.0)
        bsdf_t.inputs['Metallic'].default_value = 0.70
        bsdf_t.inputs['Roughness'].default_value = 0.32
        
    # 3. Glowing Sensor Eye / Thruster Core
    mat_glow = bpy.data.materials.new("Mat_HelionGlow")
    mat_glow.use_nodes = True
    bsdf_g = mat_glow.node_tree.nodes.get("Principled BSDF")
    if bsdf_g:
        bsdf_g.inputs['Base Color'].default_value = (1.0, 0.15, 0.20, 1.0)
        bsdf_g.inputs['Roughness'].default_value = 0.15
        if 'Emission Color' in bsdf_g.inputs:
            bsdf_g.inputs['Emission Color'].default_value = (1.0, 0.15, 0.20, 1.0)
            bsdf_g.inputs['Emission Strength'].default_value = 5.0
            
    # 4. Burnished Gunmetal Engine / Cannons
    mat_metal = bpy.data.materials.new("Mat_HelionEngine")
    mat_metal.use_nodes = True
    bsdf_m = mat_metal.node_tree.nodes.get("Principled BSDF")
    if bsdf_m:
        bsdf_m.inputs['Base Color'].default_value = (0.28, 0.30, 0.33, 1.0)
        bsdf_m.inputs['Metallic'].default_value = 0.95
        bsdf_m.inputs['Roughness'].default_value = 0.22

    return mat_hull, mat_trim, mat_glow, mat_metal

# -----------------------------------------------------------------------------
# 1. "Stalker-4" Tactical Recon Drone (Delta-Canard Stealth UCAV)
# -----------------------------------------------------------------------------
def build_stalker4_recon():
    clear_scene()
    mat_hull, mat_trim, mat_glow, mat_metal = create_pbr_materials()
    
    # Root object
    root = bpy.data.objects.new("Drone_Stalker4_Root", None)
    bpy.context.collection.objects.link(root)
    
    # Fuselage Lifting Body: faceted stealth wedge
    # Forward: -Y, Up: +Z, Wings: +/- X
    bm = bmesh.new()
    
    # Vertices for half-hull (mirrored)
    # Nose apex at (0, -3.6, 0.1)
    pts = [
        (0.0, -3.6, 0.1),       # 0: Nose tip
        (0.45, -2.4, 0.25),     # 1: Nose chine
        (1.1, -1.0, 0.35),      # 2: Forward shoulder
        (3.2, 1.8, 0.15),       # 3: Wingtip
        (2.9, 2.6, 0.12),       # 4: Wing trailing edge outer
        (0.8, 2.8, 0.40),       # 5: Wing root trailing edge
        (0.0, 3.2, 0.42),       # 6: Aft nozzle spine top
        (0.0, 3.2, -0.15),      # 7: Aft nozzle spine bottom
        (0.7, 2.8, -0.25),      # 8: Ventral wing root
        (1.0, -1.0, -0.30),     # 9: Ventral shoulder
        (0.4, -2.4, -0.22),     # 10: Ventral nose chine
        (0.0, -3.6, -0.1)       # 11: Ventral nose tip
    ]
    
    # Build complete symmetrical mesh
    v_top = []
    v_bot = []
    
    # Left side (+X)
    v_left = [bm.verts.new((x, y, z)) for x, y, z in pts]
    # Right side (-X)
    v_right = [bm.verts.new((-x if x != 0 else 0, y, z)) for x, y, z in pts]
    
    bm.verts.ensure_lookup_table()
    
    # Faces: Top deck left
    bm.faces.new((v_left[0], v_left[1], v_left[2]))
    bm.faces.new((v_left[0], v_left[2], v_left[6]))
    bm.faces.new((v_left[2], v_left[3], v_left[4], v_left[5]))
    bm.faces.new((v_left[2], v_left[5], v_left[6]))
    
    # Faces: Top deck right
    bm.faces.new((v_right[0], v_right[2], v_right[1]))
    bm.faces.new((v_right[0], v_right[6], v_right[2]))
    bm.faces.new((v_right[2], v_right[5], v_right[4], v_right[3]))
    bm.faces.new((v_right[2], v_right[6], v_right[5]))
    
    # Faces: Bottom deck left
    bm.faces.new((v_left[11], v_left[9], v_left[10]))
    bm.faces.new((v_left[11], v_left[7], v_left[9]))
    bm.faces.new((v_left[9], v_left[8], v_left[4], v_left[3]))
    bm.faces.new((v_left[9], v_left[7], v_left[8]))
    
    # Faces: Bottom deck right
    bm.faces.new((v_right[11], v_right[10], v_right[9]))
    bm.faces.new((v_right[11], v_right[9], v_right[7]))
    bm.faces.new((v_right[9], v_right[3], v_right[4], v_right[8]))
    bm.faces.new((v_right[9], v_right[8], v_right[7]))
    
    # Chine side faces: Left
    bm.faces.new((v_left[0], v_left[11], v_left[10], v_left[1]))
    bm.faces.new((v_left[1], v_left[10], v_left[9], v_left[2]))
    
    # Chine side faces: Right
    bm.faces.new((v_right[0], v_right[1], v_right[10], v_right[11]))
    bm.faces.new((v_right[1], v_right[2], v_right[9], v_right[10]))
    
    # Aft nozzle transom face
    bm.faces.new((v_left[6], v_left[5], v_left[8], v_left[7]))
    bm.faces.new((v_right[6], v_right[7], v_right[8], v_right[5]))
    
    bm.normal_update()
    for f in bm.faces:
        f.smooth = True
        
    hull_mesh = bpy.data.meshes.new("Stalker4_Hull_Mesh")
    bm.to_mesh(hull_mesh)
    bm.free()
    
    hull_obj = bpy.data.objects.new("Drone_Body", hull_mesh)
    bpy.context.collection.objects.link(hull_obj)
    hull_obj.parent = root
    hull_obj.data.materials.append(mat_hull)
    hull_obj.data.materials.append(mat_trim)
    
    # Recessed Dorsal Intake Scoop (Y: -0.8 to +1.2, Z: +0.4)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 0.2, 0.45)
    )
    intake = bpy.context.active_object
    intake.name = "DorsalIntake"
    intake.scale = (0.7, 1.4, 0.25)
    intake.data.materials.append(mat_trim)
    intake.parent = root
    
    # Twin Canted Vertical Rudders (35-degree cant outward)
    for sign, side in [(-1, "R"), (1, "L")]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 1.8, 2.2, 0.65)
        )
        fin = bpy.context.active_object
        fin.name = f"RudderFin_{side}"
        fin.scale = (0.08, 0.8, 0.75)
        fin.rotation_euler = (math.radians(-10), math.radians(sign * 28), 0)
        fin.data.materials.append(mat_trim)
        fin.parent = root
        
    # Forward Crimson Optical Seeker Eye (Gimbal Turret at chin)
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16,
        ring_count=12,
        radius=0.28,
        location=(0.0, -2.8, -0.22)
    )
    eye = bpy.context.active_object
    eye.name = "SensorEye"
    eye.data.materials.append(mat_glow)
    eye.parent = root
    
    # Engine Exhaust Nozzle with internal red glow
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=0.42,
        depth=0.5,
        location=(0.0, 3.1, 0.12)
    )
    nozzle = bpy.context.active_object
    nozzle.name = "EngineNozzle"
    nozzle.rotation_euler = (math.radians(90), 0, 0)
    nozzle.data.materials.append(mat_metal)
    nozzle.parent = root
    
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=0.34,
        depth=0.1,
        location=(0.0, 3.25, 0.12)
    )
    plume_core = bpy.context.active_object
    plume_core.name = "EnginePlumeCore"
    plume_core.rotation_euler = (math.radians(90), 0, 0)
    plume_core.data.materials.append(mat_glow)
    plume_core.parent = root
    
    return root

# -----------------------------------------------------------------------------
# 2. "Razor" High-Speed Skirmisher Interceptor (Swept Canard Jet)
# -----------------------------------------------------------------------------
def build_razor_skirmisher():
    clear_scene()
    mat_hull, mat_trim, mat_glow, mat_metal = create_pbr_materials()
    
    root = bpy.data.objects.new("Drone_Razor_Root", None)
    bpy.context.collection.objects.link(root)
    
    # Needle-nosed supersonic fuselage
    bpy.ops.mesh.primitive_cone_add(
        vertices=12,
        radius1=0.65,
        radius2=0.08,
        depth=5.2,
        location=(0.0, -1.2, 0.0)
    )
    fuselage_fwd = bpy.context.active_object
    fuselage_fwd.name = "FuselageForward"
    fuselage_fwd.rotation_euler = (math.radians(-90), 0, 0)
    fuselage_fwd.scale = (1.0, 0.65, 1.0)
    fuselage_fwd.data.materials.append(mat_hull)
    fuselage_fwd.parent = root
    
    # Aft Fuselage Block
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 2.2, 0.0)
    )
    fuselage_aft = bpy.context.active_object
    fuselage_aft.name = "FuselageAft"
    fuselage_aft.scale = (1.4, 2.4, 0.6)
    fuselage_aft.data.materials.append(mat_hull)
    fuselage_aft.parent = root
    
    # Swept Wings (Wingspan ~5.2m)
    for sign, side in [(-1, "R"), (1, "L")]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 1.6, 1.8, 0.0)
        )
        wing = bpy.context.active_object
        wing.name = f"SweptWing_{side}"
        wing.scale = (2.2, 1.6, 0.08)
        wing.rotation_euler = (0, 0, math.radians(-sign * 32))
        wing.data.materials.append(mat_hull)
        wing.parent = root
        
        # Wingtip Vertical Winglet
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 2.7, 2.4, 0.3)
        )
        wlet = bpy.context.active_object
        wlet.name = f"Winglet_{side}"
        wlet.scale = (0.06, 0.6, 0.6)
        wlet.data.materials.append(mat_trim)
        wlet.parent = root
        
        # Underslung 20mm Kinetic Gun Blister
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=0.10,
            depth=1.8,
            location=(sign * 0.75, -0.6, -0.32)
        )
        cannon = bpy.context.active_object
        cannon.name = f"Autocannon_{side}"
        cannon.rotation_euler = (math.radians(90), 0, 0)
        cannon.data.materials.append(mat_metal)
        cannon.parent = root
        
    # Forward Canards
    for sign, side in [(-1, "R"), (1, "L")]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 0.75, -2.0, 0.06)
        )
        canard = bpy.context.active_object
        canard.name = f"Canard_{side}"
        canard.scale = (0.65, 0.45, 0.05)
        canard.rotation_euler = (0, 0, math.radians(-sign * 25))
        canard.data.materials.append(mat_trim)
        canard.parent = root
        
    # Dual Vectoring Engine Nozzles
    for sign, side in [(-1, "R"), (1, "L")]:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=12,
            radius=0.32,
            depth=0.6,
            location=(sign * 0.45, 3.4, 0.0)
        )
        eng = bpy.context.active_object
        eng.name = f"JetNozzle_{side}"
        eng.rotation_euler = (math.radians(90), 0, 0)
        eng.data.materials.append(mat_metal)
        eng.parent = root
        
        # Plume glow
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=0.26,
            depth=0.08,
            location=(sign * 0.45, 3.65, 0.0)
        )
        glow = bpy.context.active_object
        glow.name = f"PlumeGlow_{side}"
        glow.rotation_euler = (math.radians(90), 0, 0)
        glow.data.materials.append(mat_glow)
        glow.parent = root
        
    # Dorsal Sensor Spine
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 0.4, 0.38)
    )
    spine = bpy.context.active_object
    spine.name = "AvionicsSpine"
    spine.scale = (0.22, 3.4, 0.22)
    spine.data.materials.append(mat_trim)
    spine.parent = root
    
    return root

# -----------------------------------------------------------------------------
# 3. "Strikefly" Heavy Dive Bomber Drone (Armored Delta with Bomb Bay)
# -----------------------------------------------------------------------------
def build_strikefly_bomber():
    clear_scene()
    mat_hull, mat_trim, mat_glow, mat_metal = create_pbr_materials()
    
    root = bpy.data.objects.new("Drone_Strikefly_Root", None)
    bpy.context.collection.objects.link(root)
    
    # Heavy armored central fuselage block (Length 8.2m, Width 2.4m, Height 1.6m)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 0.2, 0.0)
    )
    body = bpy.context.active_object
    body.name = "HeavyFuselage"
    body.scale = (2.2, 6.4, 1.4)
    body.data.materials.append(mat_hull)
    body.parent = root
    
    # Blunt Armored Nose Ram
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -3.4, 0.0)
    )
    nose = bpy.context.active_object
    nose.name = "ArmoredNose"
    nose.scale = (1.4, 1.6, 1.1)
    nose.data.materials.append(mat_trim)
    nose.parent = root
    
    # Heavy Cranked-Arrow Delta Wings (Wingspan ~8.5m)
    for sign, side in [(-1, "R"), (1, "L")]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 2.8, 0.8, -0.1)
        )
        wing = bpy.context.active_object
        wing.name = f"HeavyWing_{side}"
        wing.scale = (3.4, 3.8, 0.20)
        wing.rotation_euler = (0, 0, math.radians(-sign * 18))
        wing.data.materials.append(mat_hull)
        wing.parent = root
        
        # Heavy Outboard Twin-Turbine Nacelle Pods
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=12,
            radius=0.55,
            depth=4.2,
            location=(sign * 2.2, 1.2, 0.2)
        )
        pod = bpy.context.active_object
        pod.name = f"EnginePod_{side}"
        pod.rotation_euler = (math.radians(90), 0, 0)
        pod.data.materials.append(mat_metal)
        pod.parent = root
        
        # Thruster exhaust glow
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=0.45,
            depth=0.1,
            location=(sign * 2.2, 3.35, 0.2)
        )
        glow = bpy.context.active_object
        glow.name = f"EngineGlow_{side}"
        glow.rotation_euler = (math.radians(90), 0, 0)
        glow.data.materials.append(mat_glow)
        glow.parent = root
        
        # Under-wing Heavy Ordnance Rocket Rail
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 3.6, 0.6, -0.35)
        )
        rail = bpy.context.active_object
        rail.name = f"BombPylon_{side}"
        rail.scale = (0.25, 2.6, 0.22)
        rail.data.materials.append(mat_metal)
        rail.parent = root
        
    # Ventral Bomb Bay Blister (Centerline, Y: -1.0 to +1.8, Z: -0.85)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 0.4, -0.75)
    )
    bay = bpy.context.active_object
    bay.name = "VentralBombBay"
    bay.scale = (1.5, 3.2, 0.45)
    bay.data.materials.append(mat_trim)
    bay.parent = root
    
    # Heavy Dorsal Armor Ridge with Crimson Optics
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -1.2, 0.85)
    )
    bridge = bpy.context.active_object
    bridge.name = "TargetingBridge"
    bridge.scale = (0.8, 1.8, 0.4)
    bridge.data.materials.append(mat_trim)
    bridge.parent = root
    
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=0.25,
        depth=0.6,
        location=(0.0, -2.1, 0.85)
    )
    optic = bpy.context.active_object
    optic.name = "OpticTargeter"
    optic.rotation_euler = (math.radians(90), 0, 0)
    optic.data.materials.append(mat_glow)
    optic.parent = root
    
    return root

def main():
    out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "godot_project", "assets", "meshes", "vehicles"))
    os.makedirs(out_dir, exist_ok=True)
    
    print("==============================================================")
    print(" Generating Helion Combat Drone Fleet via Blender 4.2 ")
    print("==============================================================")
    
    # 1. "Stalker-4" Tactical Recon Drone
    print("\n[1/3] Modeling 'Stalker-4' Tactical Recon Drone (Delta UCAV)...")
    stalker = build_stalker4_recon()
    bpy.ops.object.select_all(action='SELECT')
    out_stalker = os.path.join(out_dir, "drone_stalker4_recon.glb")
    bpy.ops.export_scene.gltf(filepath=out_stalker, export_format='GLB', use_selection=True)
    print(f"  -> Exported: {out_stalker}")
    
    # 2. "Razor" High-Speed Skirmisher Interceptor
    print("\n[2/3] Modeling 'Razor' Skirmisher Interceptor Drone...")
    razor = build_razor_skirmisher()
    bpy.ops.object.select_all(action='SELECT')
    out_razor = os.path.join(out_dir, "drone_razor_skirmisher.glb")
    bpy.ops.export_scene.gltf(filepath=out_razor, export_format='GLB', use_selection=True)
    print(f"  -> Exported: {out_razor}")
    
    # 3. "Strikefly" Heavy Dive Bomber Drone
    print("\n[3/3] Modeling 'Strikefly' Heavy Dive Bomber Drone...")
    bomber = build_strikefly_bomber()
    bpy.ops.object.select_all(action='SELECT')
    out_bomber = os.path.join(out_dir, "drone_strikefly_bomber.glb")
    bpy.ops.export_scene.gltf(filepath=out_bomber, export_format='GLB', use_selection=True)
    print(f"  -> Exported: {out_bomber}")
    
    print("\n[SUCCESS] Helion Combat Drone Fleet successfully modeled and exported!")

if __name__ == "__main__":
    main()
