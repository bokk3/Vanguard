# -*- coding: utf-8 -*-
"""
Spire-45 Tactical Electronic Warfare Jamming Array Generator for Project Vanguard.
Builds a high-detail 45m tactical mast with:
1. Octagonal reinforced concrete bunker foundation with blast doors & buttresses
2. Hexagonal steel lattice mast with horizontal ring frames & diagonal X-trusses
3. Central high-voltage waveguide core conduit
4. Dual 3.4m steerable parabolic microwave dishes with quad feedhorn struts at 24m
5. Upper rotating ECM Emitter Crown (42m) with cooling heatsinks, strobe outriggers & radome
Exports game-ready GLB directly to godot_project/assets/meshes/environment/.
"""

import bpy
import bmesh
import math
import os
import sys

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_spire45():
    clear_scene()
    
    # -------------------------------------------------------------
    # Materials
    # -------------------------------------------------------------
    mat_concrete = bpy.data.materials.new("Mat_BunkerConcrete")
    mat_concrete.use_nodes = True
    bsdf_c = mat_concrete.node_tree.nodes.get("Principled BSDF")
    if bsdf_c:
        bsdf_c.inputs['Base Color'].default_value = (0.22, 0.24, 0.27, 1.0)
        bsdf_c.inputs['Roughness'].default_value = 0.85
        
    mat_steel = bpy.data.materials.new("Mat_StructuralSteel")
    mat_steel.use_nodes = True
    bsdf_s = mat_steel.node_tree.nodes.get("Principled BSDF")
    if bsdf_s:
        bsdf_s.inputs['Base Color'].default_value = (0.35, 0.38, 0.42, 1.0)
        bsdf_s.inputs['Metallic'].default_value = 0.85
        bsdf_s.inputs['Roughness'].default_value = 0.35
        
    mat_dish = bpy.data.materials.new("Mat_MicrowaveDish")
    mat_dish.use_nodes = True
    bsdf_d = mat_dish.node_tree.nodes.get("Principled BSDF")
    if bsdf_d:
        bsdf_d.inputs['Base Color'].default_value = (0.75, 0.78, 0.82, 1.0)
        bsdf_d.inputs['Metallic'].default_value = 0.6
        bsdf_d.inputs['Roughness'].default_value = 0.3
        
    mat_ecm = bpy.data.materials.new("Mat_ECMTransmitter")
    mat_ecm.use_nodes = True
    bsdf_e = mat_ecm.node_tree.nodes.get("Principled BSDF")
    if bsdf_e:
        bsdf_e.inputs['Base Color'].default_value = (0.15, 0.17, 0.20, 1.0)
        bsdf_e.inputs['Metallic'].default_value = 0.9
        bsdf_e.inputs['Roughness'].default_value = 0.25
        
    mat_radome = bpy.data.materials.new("Mat_CrimsonRadome")
    mat_radome.use_nodes = True
    bsdf_r = mat_radome.node_tree.nodes.get("Principled BSDF")
    if bsdf_r:
        bsdf_r.inputs['Base Color'].default_value = (0.9, 0.1, 0.15, 1.0)
        bsdf_r.inputs['Roughness'].default_value = 0.2
        if 'Emission Color' in bsdf_r.inputs:
            bsdf_r.inputs['Emission Color'].default_value = (1.0, 0.15, 0.2, 1.0)
            bsdf_r.inputs['Emission Strength'].default_value = 4.0

    # -------------------------------------------------------------
    # 1. Base Bunker (Octagonal Foundation, 14m diameter, 4m height)
    # -------------------------------------------------------------
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=7.0,
        depth=4.0,
        location=(0, 0, 2.0)
    )
    bunker = bpy.context.active_object
    bunker.name = "Spire_BunkerBase"
    bunker.data.materials.append(mat_concrete)
    
    # 4 corner buttress pilasters
    for angle in [45, 135, 225, 315]:
        rad = math.radians(angle)
        bx = math.cos(rad) * 6.5
        by = math.sin(rad) * 6.5
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(bx, by, 2.0)
        )
        pil = bpy.context.active_object
        pil.scale = (2.2, 2.2, 4.0)
        pil.data.materials.append(mat_concrete)
        pil.parent = bunker
        
    # Armored entrance door
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(0, -6.8, 1.6)
    )
    door = bpy.context.active_object
    door.name = "BunkerDoor"
    door.scale = (2.4, 0.6, 3.2)
    door.data.materials.append(mat_steel)
    door.parent = bunker

    # -------------------------------------------------------------
    # 2. Lattice Tower Mast (Hexagonal Chords & X-Bracing, Y: 4m - 42m)
    # -------------------------------------------------------------
    bm = bmesh.new()
    levels = 9
    h_start = 4.0
    h_end = 42.0
    r_bot = 3.2
    r_top = 1.8
    
    ring_verts = []
    for i in range(levels):
        t = i / float(levels - 1)
        h = h_start + t * (h_end - h_start)
        r = r_bot + t * (r_top - r_bot)
        
        current_ring = []
        for v_idx in range(6):
            theta = (v_idx / 6.0) * 2.0 * math.pi
            x = math.cos(theta) * r
            y = math.sin(theta) * r
            v = bm.verts.new((x, y, h))
            current_ring.append(v)
        ring_verts.append(current_ring)
        
    bm.verts.ensure_lookup_table()
    
    # Edges: Vertical chords
    for i in range(levels - 1):
        for v_idx in range(6):
            bm.edges.new((ring_verts[i][v_idx], ring_verts[i + 1][v_idx]))
            
    # Edges: Horizontal ring frames
    for i in range(levels):
        for v_idx in range(6):
            bm.edges.new((ring_verts[i][v_idx], ring_verts[i][(v_idx + 1) % 6]))
            
    # Edges: Diagonal X-trusses
    for i in range(levels - 1):
        for v_idx in range(6):
            v_next = (v_idx + 1) % 6
            bm.edges.new((ring_verts[i][v_idx], ring_verts[i + 1][v_next]))
            bm.edges.new((ring_verts[i][v_next], ring_verts[i + 1][v_idx]))
            
    mast_mesh = bpy.data.meshes.new("LatticeMast_Mesh")
    bm.to_mesh(mast_mesh)
    bm.free()
    
    mast_obj = bpy.data.objects.new("Spire_LatticeMast", mast_mesh)
    bpy.context.collection.objects.link(mast_obj)
    mast_obj.parent = bunker
    
    # Convert wireframe edges into solid tubular steel beams
    bpy.context.view_layer.objects.active = mast_obj
    mast_obj.select_set(True)
    bpy.ops.object.convert(target='CURVE')
    mast_obj.data.bevel_depth = 0.12
    mast_obj.data.bevel_resolution = 2
    bpy.ops.object.convert(target='MESH')
    mast_obj.data.materials.append(mat_steel)
    
    # Central waveguide conduit core
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=0.5,
        depth=(h_end - h_start),
        location=(0, 0, (h_start + h_end) * 0.5)
    )
    conduit = bpy.context.active_object
    conduit.name = "CentralWaveguide"
    conduit.data.materials.append(mat_steel)
    conduit.parent = bunker

    # -------------------------------------------------------------
    # 3. Dual Steerable Microwave Dishes (at 24m)
    # -------------------------------------------------------------
    for side, sign in [("L", -1), ("R", 1)]:
        dish_mount_z = 24.0
        dish_x = sign * 3.4
        
        # Parabolic dish mesh (curved cone/sphere slice)
        bpy.ops.mesh.primitive_cone_add(
            vertices=20,
            radius1=1.8,
            radius2=0.3,
            depth=1.1,
            location=(dish_x, 0, dish_mount_z)
        )
        dish = bpy.context.active_object
        dish.name = f"MicrowaveDish_{side}"
        dish.rotation_euler = (0, math.radians(90 * sign), 0)
        dish.data.materials.append(mat_dish)
        dish.parent = bunker
        
        # Sub-reflector feedhorn on 3 struts
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=0.22,
            depth=0.5,
            location=(dish_x + sign * 1.0, 0, dish_mount_z)
        )
        feed = bpy.context.active_object
        feed.name = f"FeedHorn_{side}"
        feed.rotation_euler = (0, math.radians(90 * sign), 0)
        feed.data.materials.append(mat_steel)
        feed.parent = dish

    # -------------------------------------------------------------
    # 4. Rotating ECM Emitter Crown (Y: 41m - 46m)
    # -------------------------------------------------------------
    ecm_root = bpy.data.objects.new("ECM_Emitter_Head", None)
    ecm_root.location = (0, 0, 42.0)
    bpy.context.collection.objects.link(ecm_root)
    ecm_root.parent = bunker
    
    # Cylindrical transmitter core
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=16,
        radius=2.0,
        depth=2.8,
        location=(0, 0, 42.0)
    )
    ecm_core = bpy.context.active_object
    ecm_core.name = "ECM_CoreHousing"
    ecm_core.data.materials.append(mat_ecm)
    ecm_core.parent = ecm_root
    
    # 8 radial heatsink cooling blades
    for i in range(8):
        theta = (i / 8.0) * 2.0 * math.pi
        hx = math.cos(theta) * 2.2
        hy = math.sin(theta) * 2.2
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(hx, hy, 42.0)
        )
        fin = bpy.context.active_object
        fin.name = f"HeatsinkFin_{i}"
        fin.scale = (0.08, 0.6, 2.2)
        fin.rotation_euler = (0, 0, theta)
        fin.data.materials.append(mat_steel)
        fin.parent = ecm_root
        
    # 4 radial strobe outriggers
    for i in range(4):
        theta = (i / 4.0) * 2.0 * math.pi
        ox = math.cos(theta) * 3.2
        oy = math.sin(theta) * 3.2
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(ox * 0.5, oy * 0.5, 42.0)
        )
        arm = bpy.context.active_object
        arm.scale = (0.2, 3.2, 0.2)
        arm.rotation_euler = (0, 0, theta + math.pi * 0.5)
        arm.data.materials.append(mat_steel)
        arm.parent = ecm_root
        
        # Red strobe beacon cap
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=12,
            ring_count=8,
            radius=0.35,
            location=(ox, oy, 42.0)
        )
        strobe = bpy.context.active_object
        strobe.name = f"ECM_Strobe_{i}"
        strobe.data.materials.append(mat_radome)
        strobe.parent = ecm_root
        
    # Top Conical Radome Spire Summit (43.4m to 45.8m)
    bpy.ops.mesh.primitive_cone_add(
        vertices=16,
        radius1=1.8,
        radius2=0.08,
        depth=2.4,
        location=(0, 0, 44.6)
    )
    radome = bpy.context.active_object
    radome.name = "Radome_Spire"
    radome.data.materials.append(mat_radome)
    radome.parent = ecm_root
    
    return bunker

def main():
    out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "godot_project", "assets", "meshes", "environment"))
    os.makedirs(out_dir, exist_ok=True)
    
    print("==============================================================")
    print(" Generating 'Spire-45' Electronic Warfare Jammer via Blender ")
    print("==============================================================")
    
    root_obj = create_spire45()
    
    # Select all hierarchy for export
    bpy.ops.object.select_all(action='SELECT')
    out_file = os.path.join(out_dir, "spire45_jamming_array.glb")
    
    bpy.ops.export_scene.gltf(
        filepath=out_file,
        export_format='GLB',
        use_selection=True
    )
    print(f"\n[SUCCESS] Exported: {out_file}")

if __name__ == "__main__":
    main()
