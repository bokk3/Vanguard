# -*- coding: utf-8 -*-
"""
Capital Escort & Ace Boss Model Generator for Project Vanguard (Blender 4.2+).
Builds two high-fidelity flagship aerospace vessels:
1. Directorate C-900 'Olympus-4' Heavy Suborbital Transport (66m length)
2. Helion SG-99 'Combine Ghost' Forward-Swept Wing Ace Fighter (13.6m length)
Exports game-ready GLBs directly to godot_project/assets/meshes/vehicles/.
"""

import bpy
import bmesh
import math
import os
import sys

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

# -----------------------------------------------------------------------------
# 1. Directorate C-900 "Olympus-4" Heavy Suborbital Transport (66m Length)
# -----------------------------------------------------------------------------
def build_olympus4_transport():
    clear_scene()
    
    # Directorate Materials
    mat_hull = bpy.data.materials.new("Mat_OlympusHull")
    mat_hull.use_nodes = True
    bsdf_h = mat_hull.node_tree.nodes.get("Principled BSDF")
    if bsdf_h:
        bsdf_h.inputs['Base Color'].default_value = (0.16, 0.20, 0.26, 1.0)
        bsdf_h.inputs['Metallic'].default_value = 0.85
        bsdf_h.inputs['Roughness'].default_value = 0.32
        
    mat_armor = bpy.data.materials.new("Mat_OlympusArmorPlates")
    mat_armor.use_nodes = True
    bsdf_a = mat_armor.node_tree.nodes.get("Principled BSDF")
    if bsdf_a:
        bsdf_a.inputs['Base Color'].default_value = (0.28, 0.32, 0.38, 1.0)
        bsdf_a.inputs['Metallic'].default_value = 0.90
        bsdf_a.inputs['Roughness'].default_value = 0.24
        
    mat_gold = bpy.data.materials.new("Mat_DirectorateGold")
    mat_gold.use_nodes = True
    bsdf_g = mat_gold.node_tree.nodes.get("Principled BSDF")
    if bsdf_g:
        bsdf_g.inputs['Base Color'].default_value = (0.95, 0.65, 0.12, 1.0)
        bsdf_g.inputs['Metallic'].default_value = 0.80
        bsdf_g.inputs['Roughness'].default_value = 0.30
        
    mat_ion = bpy.data.materials.new("Mat_IonEngineGlow")
    mat_ion.use_nodes = True
    bsdf_i = mat_ion.node_tree.nodes.get("Principled BSDF")
    if bsdf_i:
        bsdf_i.inputs['Base Color'].default_value = (0.1, 0.7, 1.0, 1.0)
        bsdf_i.inputs['Roughness'].default_value = 0.15
        if 'Emission Color' in bsdf_i.inputs:
            bsdf_i.inputs['Emission Color'].default_value = (0.15, 0.85, 1.0, 1.0)
            bsdf_i.inputs['Emission Strength'].default_value = 6.0
            
    mat_bridge = bpy.data.materials.new("Mat_CommandBridgeGlass")
    mat_bridge.use_nodes = True
    bsdf_b = mat_bridge.node_tree.nodes.get("Principled BSDF")
    if bsdf_b:
        bsdf_b.inputs['Base Color'].default_value = (0.05, 0.45, 0.65, 1.0)
        bsdf_b.inputs['Roughness'].default_value = 0.1
        if 'Emission Color' in bsdf_b.inputs:
            bsdf_b.inputs['Emission Color'].default_value = (0.1, 0.6, 0.9, 1.0)
            bsdf_b.inputs['Emission Strength'].default_value = 2.5

    root = bpy.data.objects.new("Transport_Olympus4_Root", None)
    bpy.context.collection.objects.link(root)
    
    # 1. Main Lifting Body Fuselage (Length 52m, Width 22m, Height 9m)
    # Forward: -Y, Aft: +Y
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 2.0, 0.0)
    )
    main_hull = bpy.context.active_object
    main_hull.name = "Olympus_MainHull"
    main_hull.scale = (20.0, 48.0, 8.5)
    main_hull.data.materials.append(mat_hull)
    main_hull.parent = root
    
    # 2. Forward Armored Bow Wedge (Length 14m)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4,
        radius1=14.0,
        radius2=4.0,
        depth=14.0,
        location=(0.0, -28.0, 0.0)
    )
    bow = bpy.context.active_object
    bow.name = "Olympus_Bow"
    bow.rotation_euler = (math.radians(-90), 0, math.radians(45))
    bow.scale = (0.72, 0.35, 1.0)
    bow.data.materials.append(mat_armor)
    bow.parent = root
    
    # 3. Panoramic Command Bridge (Dorsal forward at Y = -22m, Z = 5.2m)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -21.0, 5.2)
    )
    bridge = bpy.context.active_object
    bridge.name = "CommandBridge"
    bridge.scale = (7.0, 8.0, 2.8)
    bridge.data.materials.append(mat_bridge)
    bridge.parent = root
    
    # Bridge visor brow
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -24.0, 6.2)
    )
    brow = bpy.context.active_object
    brow.name = "BridgeBrow"
    brow.scale = (7.6, 2.5, 0.9)
    brow.data.materials.append(mat_gold)
    brow.parent = root
    
    # 4. Heavy Cargo Bay Container Sponsons (Width 28m)
    for sign, side in [(-1, "R"), (1, "L")]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 12.5, 4.0, -0.5)
        )
        sponson = bpy.context.active_object
        sponson.name = f"CargoSponson_{side}"
        sponson.scale = (5.5, 34.0, 6.5)
        sponson.data.materials.append(mat_armor)
        sponson.parent = root
        
        # External structural ribbing frames (5 ribs along length)
        for r_idx in range(5):
            ry = -10.0 + r_idx * 7.0
            bpy.ops.mesh.primitive_cube_add(
                size=1.0,
                location=(sign * 13.0, ry, -0.5)
            )
            rib = bpy.context.active_object
            rib.name = f"CargoRib_{side}_{r_idx}"
            rib.scale = (6.0, 1.2, 7.2)
            rib.data.materials.append(mat_gold)
            rib.parent = sponson

    # 5. Quad Heavy Aerospike Ion Engines (2 Port, 2 Starboard at Y = 27m)
    engine_positions = [
        (-7.0, 26.5, 2.5, "UpperL"),
        (7.0, 26.5, 2.5, "UpperR"),
        (-7.0, 26.5, -2.5, "LowerL"),
        (7.0, 26.5, -2.5, "LowerR")
    ]
    for ex, ey, ez, ename in engine_positions:
        # Engine Nacelle Cowling
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=16,
            radius=2.6,
            depth=9.0,
            location=(ex, ey, ez)
        )
        nacelle = bpy.context.active_object
        nacelle.name = f"IonNacelle_{ename}"
        nacelle.rotation_euler = (math.radians(90), 0, 0)
        nacelle.data.materials.append(mat_armor)
        nacelle.parent = root
        
        # Glowing Ion Core
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=12,
            radius=2.0,
            depth=0.8,
            location=(ex, ey + 4.6, ez)
        )
        core = bpy.context.active_object
        core.name = f"IonGlow_{ename}"
        core.rotation_euler = (math.radians(90), 0, 0)
        core.data.materials.append(mat_ion)
        core.parent = root
        
    # 6. Dorsal Radiator Panels & Communications Spine
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 6.0, 4.8)
    )
    spine = bpy.context.active_object
    spine.name = "DorsalRadiatorSpine"
    spine.scale = (6.0, 28.0, 1.4)
    spine.data.materials.append(mat_armor)
    spine.parent = root
    
    # 7. Twin Dorsal Point-Defense Turret Sponsons
    for sign, side in [(-1, "R"), (1, "L")]:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=12,
            radius=1.8,
            depth=1.2,
            location=(sign * 4.5, -6.0, 5.2)
        )
        turret = bpy.context.active_object
        turret.name = f"PDT_Turret_{side}"
        turret.data.materials.append(mat_hull)
        turret.parent = root
        
        # Dual barrels
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=0.2,
            depth=3.2,
            location=(sign * 4.5, -8.0, 5.6)
        )
        barrel = bpy.context.active_object
        barrel.name = f"PDT_Barrels_{side}"
        barrel.rotation_euler = (math.radians(90), 0, 0)
        barrel.data.materials.append(mat_armor)
        barrel.parent = turret

    return root

# -----------------------------------------------------------------------------
# 2. Helion SG-99 "Combine Ghost" Forward-Swept Wing Ace Fighter (13.6m Length)
# -----------------------------------------------------------------------------
def build_combine_ghost_boss():
    clear_scene()
    
    # Helion Ace PBR Materials
    mat_hull = bpy.data.materials.new("Mat_GhostObsidianHull")
    mat_hull.use_nodes = True
    bsdf_h = mat_hull.node_tree.nodes.get("Principled BSDF")
    if bsdf_h:
        bsdf_h.inputs['Base Color'].default_value = (0.08, 0.09, 0.11, 1.0)
        bsdf_h.inputs['Metallic'].default_value = 0.92
        bsdf_h.inputs['Roughness'].default_value = 0.22
        
    mat_crimson = bpy.data.materials.new("Mat_GhostCrimsonPanels")
    mat_crimson.use_nodes = True
    bsdf_c = mat_crimson.node_tree.nodes.get("Principled BSDF")
    if bsdf_c:
        bsdf_c.inputs['Base Color'].default_value = (0.80, 0.06, 0.12, 1.0)
        bsdf_c.inputs['Metallic'].default_value = 0.82
        bsdf_c.inputs['Roughness'].default_value = 0.28
        
    mat_canopy = bpy.data.materials.new("Mat_GhostCrimsonCanopy")
    mat_canopy.use_nodes = True
    bsdf_k = mat_canopy.node_tree.nodes.get("Principled BSDF")
    if bsdf_k:
        bsdf_k.inputs['Base Color'].default_value = (0.9, 0.1, 0.15, 1.0)
        bsdf_k.inputs['Roughness'].default_value = 0.12
        if 'Emission Color' in bsdf_k.inputs:
            bsdf_k.inputs['Emission Color'].default_value = (1.0, 0.12, 0.18, 1.0)
            bsdf_k.inputs['Emission Strength'].default_value = 3.5
            
    mat_glow = bpy.data.materials.new("Mat_GhostThrusterGlow")
    mat_glow.use_nodes = True
    bsdf_g = mat_glow.node_tree.nodes.get("Principled BSDF")
    if bsdf_g:
        bsdf_g.inputs['Base Color'].default_value = (1.0, 0.2, 0.05, 1.0)
        bsdf_g.inputs['Roughness'].default_value = 0.1
        if 'Emission Color' in bsdf_g.inputs:
            bsdf_g.inputs['Emission Color'].default_value = (1.0, 0.25, 0.05, 1.0)
            bsdf_g.inputs['Emission Strength'].default_value = 7.0
            
    mat_metal = bpy.data.materials.new("Mat_GhostTungsten")
    mat_metal.use_nodes = True
    bsdf_m = mat_metal.node_tree.nodes.get("Principled BSDF")
    if bsdf_m:
        bsdf_m.inputs['Base Color'].default_value = (0.24, 0.26, 0.29, 1.0)
        bsdf_m.inputs['Metallic'].default_value = 0.96
        bsdf_m.inputs['Roughness'].default_value = 0.20

    root = bpy.data.objects.new("Boss_CombineGhost_Root", None)
    bpy.context.collection.objects.link(root)
    
    # 1. Chined Stealth Nose & Central Fuselage (Forward: -Y, Length 13.6m)
    # Fuselage main spine
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 0.6, 0.0)
    )
    fuselage = bpy.context.active_object
    fuselage.name = "Ghost_Fuselage"
    fuselage.scale = (2.8, 9.6, 1.4)
    fuselage.data.materials.append(mat_hull)
    fuselage.parent = root
    
    # Chined needle nose cone (Y: -4.2 to -7.2)
    bpy.ops.mesh.primitive_cone_add(
        vertices=6,
        radius1=1.4,
        radius2=0.1,
        depth=4.8,
        location=(0.0, -5.8, -0.1)
    )
    nose = bpy.context.active_object
    nose.name = "Ghost_ChinedNose"
    nose.rotation_euler = (math.radians(-90), 0, 0)
    nose.scale = (1.1, 0.55, 1.0)
    nose.data.materials.append(mat_hull)
    nose.parent = root
    
    # 2. Faceted Cockpit Canopy (Y: -3.2 to -0.6, Z: 0.9m)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -1.8, 0.95)
    )
    canopy = bpy.context.active_object
    canopy.name = "Ghost_Canopy"
    canopy.scale = (1.2, 3.2, 0.65)
    canopy.data.materials.append(mat_canopy)
    canopy.parent = root
    
    # Canopy frame border
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, -1.8, 0.75)
    )
    cframe = bpy.context.active_object
    cframe.name = "Ghost_CanopyFrame"
    cframe.scale = (1.35, 3.5, 0.35)
    cframe.data.materials.append(mat_crimson)
    cframe.parent = root
    
    # 3. Predatory Forward-Swept Wings (Wingspan 12.8m, sweeping forward 26 degrees)
    for sign, side in [(-1, "R"), (1, "L")]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 4.2, -0.4, 0.05)
        )
        wing = bpy.context.active_object
        wing.name = f"ForwardSweptWing_{side}"
        wing.scale = (4.8, 3.4, 0.18)
        # Forward sweep: positive angle for L (+X), negative for R (-X)
        wing.rotation_euler = (0, math.radians(-sign * 3), math.radians(sign * 26))
        wing.data.materials.append(mat_hull)
        wing.parent = root
        
        # Leading-Edge Crimson Armor Slat
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 4.4, -1.9, 0.08)
        )
        slat = bpy.context.active_object
        slat.name = f"WingSlat_{side}"
        slat.scale = (4.6, 0.5, 0.22)
        slat.rotation_euler = (0, math.radians(-sign * 3), math.radians(sign * 26))
        slat.data.materials.append(mat_crimson)
        slat.parent = root
        
        # Down-Canted Wingtip Stabilizer Fins
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 6.4, -1.5, -0.4)
        )
        wfin = bpy.context.active_object
        wfin.name = f"WingtipFin_{side}"
        wfin.scale = (0.12, 1.8, 1.2)
        wfin.rotation_euler = (0, math.radians(sign * 32), 0)
        wfin.data.materials.append(mat_crimson)
        wfin.parent = root
        
        # Under-wing Missile Hardpoint Rail
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 3.2, -0.2, -0.35)
        )
        rail = bpy.context.active_object
        rail.name = f"MissilePylon_{side}"
        rail.scale = (0.24, 2.6, 0.26)
        rail.data.materials.append(mat_metal)
        rail.parent = root
        
    # 4. Twin 3D Vectoring Rectangular Engine Shrouds (Aft at Y = 5.6m)
    for sign, side in [(-1, "R"), (1, "L")]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 0.95, 5.2, 0.0)
        )
        nozzle = bpy.context.active_object
        nozzle.name = f"VectorNozzle_{side}"
        nozzle.scale = (1.1, 2.2, 0.95)
        nozzle.data.materials.append(mat_metal)
        nozzle.parent = root
        
        # Internal glowing afterburner flame core
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sign * 0.95, 6.35, 0.0)
        )
        flame = bpy.context.active_object
        flame.name = f"AfterburnerGlow_{side}"
        flame.scale = (0.85, 0.2, 0.75)
        flame.data.materials.append(mat_glow)
        flame.parent = root
        
    # 5. Twin Heavy 20mm Rotary Autocannons (Chin flanks at X = +/- 0.85, Y = -3.8)
    for sign, side in [(-1, "R"), (1, "L")]:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=0.14,
            depth=3.2,
            location=(sign * 0.85, -3.8, -0.42)
        )
        gun = bpy.context.active_object
        gun.name = f"Muzzle_{side}"
        gun.rotation_euler = (math.radians(90), 0, 0)
        gun.data.materials.append(mat_metal)
        gun.parent = root
        
    # 6. Dorsal Avionics Fin & Crimson Strike Chevrons
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0.0, 1.8, 1.1)
    )
    dorsal_fin = bpy.context.active_object
    dorsal_fin.name = "DorsalAvionicsFin"
    dorsal_fin.scale = (0.22, 4.2, 1.0)
    dorsal_fin.data.materials.append(mat_crimson)
    dorsal_fin.parent = root

    return root

def main():
    out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "godot_project", "assets", "meshes", "vehicles"))
    os.makedirs(out_dir, exist_ok=True)
    
    print("==============================================================")
    print(" Generating Capital Escort & Ace Boss Models via Blender 4.2 ")
    print("==============================================================")
    
    # 1. Olympus-4 Heavy Suborbital Transport (66m)
    print("\n[1/2] Modeling Directorate C-900 'Olympus-4' Heavy Transport (66m)...")
    olympus = build_olympus4_transport()
    bpy.ops.object.select_all(action='SELECT')
    out_olympus = os.path.join(out_dir, "transport_olympus4_c900.glb")
    bpy.ops.export_scene.gltf(filepath=out_olympus, export_format='GLB', use_selection=True)
    print(f"  -> Exported: {out_olympus}")
    
    # 2. Helion SG-99 'Combine Ghost' Ace Fighter (13.6m)
    print("\n[2/2] Modeling Helion SG-99 'Combine Ghost' Forward-Swept Wing Boss (13.6m)...")
    ghost = build_combine_ghost_boss()
    bpy.ops.object.select_all(action='SELECT')
    out_ghost = os.path.join(out_dir, "boss_combine_ghost_sg99.glb")
    bpy.ops.export_scene.gltf(filepath=out_ghost, export_format='GLB', use_selection=True)
    print(f"  -> Exported: {out_ghost}")
    
    print("\n[SUCCESS] Capital Escort & Ace Boss Flagship Models exported successfully!")

if __name__ == "__main__":
    main()
