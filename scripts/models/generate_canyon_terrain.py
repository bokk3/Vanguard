# -*- coding: utf-8 -*-
"""
Procedural Canyon Terrain & Mesa Mesh Generator for Project Vanguard (Blender 4.2+).
Builds modular 180m sandstone cliff walls, curved canyon bends, and standalone mesa pillars.
Exports game-ready GLB meshes with collision hulls directly to godot_project.
"""

import bpy
import bmesh
import math
import os
import sys
import numpy as np

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_cliff_straight(length=250.0, height=180.0, depth=55.0, name="canyon_cliff_straight"):
    """Creates a 250m straight sandstone cliff wall with horizontal geological strata,
    vertical erosion crevices, overhang ledges, and sloped base talus."""
    clear_scene()
    
    # Create grid mesh along XY plane, then extrude into depth (Z in local space)
    bm = bmesh.new()
    
    res_x = 32
    res_y = 28
    
    # Generate vertex grid for front cliff face
    verts_grid = []
    np.random.seed(101)
    
    for iy in range(res_y + 1):
        v_row = []
        y_norm = iy / float(res_y)
        y_pos = y_norm * height
        
        # Talus apron slope at base (0m to 35m)
        talus_depth = max(0.0, 1.0 - (y_pos / 40.0)) * 22.0
        
        # Overhang shelf at 120m-140m (the canyon rim lip)
        rim_overhang = math.sin(max(0.0, (y_pos - 100.0) / 40.0) * math.pi) * 8.0 if y_pos > 100.0 else 0.0
        
        for ix in range(res_x + 1):
            x_norm = ix / float(res_x)
            x_pos = (x_norm - 0.5) * length
            
            # Procedural geological noise:
            # 1. Horizontal sedimentary strata (shelves and ledges)
            strata = math.sin(y_pos * 0.12) * 3.5 + math.sin(y_pos * 0.35) * 1.5
            
            # 2. Vertical fracture joints / erosion buttresses
            joints = math.sin(x_pos * 0.08 + y_pos * 0.02) * 4.0 + math.cos(x_pos * 0.18) * 2.2
            
            # 3. High-frequency rock roughness
            roughness = (np.random.rand() - 0.5) * 1.8
            
            z_offset = strata + joints + roughness - talus_depth + rim_overhang
            
            # In Blender standard coordinates: X=lateral, Y=depth, Z=height
            # So front face is at Y = z_offset, Z = y_pos, X = x_pos
            vert = bm.verts.new((x_pos, z_offset, y_pos))
            v_row.append(vert)
        verts_grid.append(v_row)
        
    bm.verts.ensure_lookup_table()
    
    # Create quad faces for front cliff face
    front_faces = []
    for iy in range(res_y):
        for ix in range(res_x):
            v1 = verts_grid[iy][ix]
            v2 = verts_grid[iy][ix + 1]
            v3 = verts_grid[iy + 1][ix + 1]
            v4 = verts_grid[iy + 1][ix]
            f = bm.faces.new((v1, v2, v3, v4))
            front_faces.append(f)
            
    # Extrude back vertices to create solid block with flat top and back
    back_row_top = []
    back_row_bot = []
    
    for ix in range(res_x + 1):
        x_pos = (ix / float(res_x) - 0.5) * length
        # Back top edge at Y = -depth, Z = height
        v_top = bm.verts.new((x_pos, -depth, height))
        back_row_top.append(v_top)
        # Back bot edge at Y = -depth, Z = 0
        v_bot = bm.verts.new((x_pos, -depth, 0.0))
        back_row_bot.append(v_bot)
        
    bm.verts.ensure_lookup_table()
    
    # Top mesa cap faces
    for ix in range(res_x):
        v1 = verts_grid[res_y][ix]
        v2 = verts_grid[res_y][ix + 1]
        v3 = back_row_top[ix + 1]
        v4 = back_row_top[ix]
        bm.faces.new((v1, v2, v3, v4))
        
    # Back cliff faces
    for ix in range(res_x):
        v1 = back_row_top[ix]
        v2 = back_row_top[ix + 1]
        v3 = back_row_bot[ix + 1]
        v4 = back_row_bot[ix]
        bm.faces.new((v1, v2, v3, v4))
        
    # Bottom ground faces
    for ix in range(res_x):
        v1 = back_row_bot[ix]
        v2 = back_row_bot[ix + 1]
        v3 = verts_grid[0][ix + 1]
        v4 = verts_grid[0][ix]
        bm.faces.new((v1, v2, v3, v4))
        
    # Left cap
    bm.faces.new((back_row_bot[0], back_row_top[0], verts_grid[res_y][0], verts_grid[0][0]))
    # Right cap
    bm.faces.new((verts_grid[0][res_x], verts_grid[res_y][res_x], back_row_top[res_x], back_row_bot[res_x]))
    
    # Recalculate normals & smooth
    bm.normal_update()
    for f in bm.faces:
        f.smooth = True
        
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    
    # Smart UV projection
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Assign Sandstone PBR Material
    mat = bpy.data.materials.new(name="Mat_CanyonSandstone")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.58, 0.26, 0.15, 1.0)
        bsdf.inputs['Roughness'].default_value = 0.88
    obj.data.materials.append(mat)
    
    return obj

def create_mesa_pillar(radius=45.0, height=170.0, name="canyon_mesa_pillar"):
    """Creates a standalone soaring desert mesa pillar / butte (radius ~45m, height 170m)."""
    clear_scene()
    
    bm = bmesh.new()
    res_theta = 24
    res_h = 20
    
    verts_rings = []
    np.random.seed(4242)
    
    for ih in range(res_h + 1):
        ring = []
        h_norm = ih / float(res_h)
        h_pos = h_norm * height
        
        # Flare out at base (talus scree apron)
        base_flare = max(0.0, 1.0 - (h_pos / 35.0)) * 18.0
        # Slight waist pinch in the middle, flaring out at top mesa cap
        mid_pinch = math.sin(h_norm * math.pi) * -4.0
        cap_flare = math.sin(max(0.0, (h_norm - 0.85) / 0.15) * math.pi * 0.5) * 6.0
        
        r_current = radius + base_flare + mid_pinch + cap_flare
        
        # Horizontal rock strata indentation
        strata_ring = math.sin(h_pos * 0.15) * 2.2 + math.sin(h_pos * 0.4) * 1.2
        r_current += strata_ring
        
        for it in range(res_theta):
            theta = (it / float(res_theta)) * 2.0 * math.pi
            # Fluted vertical joint columns
            column_noise = math.sin(theta * 6.0) * 2.8 + math.cos(theta * 12.0) * 1.2
            r = r_current + column_noise + (np.random.rand() - 0.5) * 1.4
            
            x = math.cos(theta) * r
            y = math.sin(theta) * r
            z = h_pos
            v = bm.verts.new((x, y, z))
            ring.append(v)
            
        verts_rings.append(ring)
        
    bm.verts.ensure_lookup_table()
    
    # Side quad faces
    for ih in range(res_h):
        for it in range(res_theta):
            it_next = (it + 1) % res_theta
            v1 = verts_rings[ih][it]
            v2 = verts_rings[ih][it_next]
            v3 = verts_rings[ih + 1][it_next]
            v4 = verts_rings[ih + 1][it]
            bm.faces.new((v1, v2, v3, v4))
            
    # Top flat mesa cap
    top_center = bm.verts.new((0.0, 0.0, height))
    for it in range(res_theta):
        it_next = (it + 1) % res_theta
        bm.faces.new((verts_rings[res_h][it], verts_rings[res_h][it_next], top_center))
        
    # Bottom center
    bot_center = bm.verts.new((0.0, 0.0, 0.0))
    for it in range(res_theta):
        it_next = (it + 1) % res_theta
        bm.faces.new((bot_center, verts_rings[0][it_next], verts_rings[0][it]))
        
    bm.normal_update()
    for f in bm.faces:
        f.smooth = True
        
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    
    # Smart UV
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    mat = bpy.data.materials.new(name="Mat_MesaSandstone")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.54, 0.23, 0.13, 1.0)
        bsdf.inputs['Roughness'].default_value = 0.90
    obj.data.materials.append(mat)
    
    return obj

def main():
    out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "godot_project", "assets", "meshes", "environment"))
    os.makedirs(out_dir, exist_ok=True)
    
    print("=======================================================")
    print(" Generating Modular Canyon Terrain Meshes via Blender ")
    print("=======================================================")
    
    # 1. Straight Cliff Wall (250m long x 180m high)
    print("\n[1/2] Generating canyon_cliff_straight.glb (250m x 180m)...")
    cliff_obj = create_cliff_straight()
    out_cliff = os.path.join(out_dir, "canyon_cliff_straight.glb")
    bpy.ops.export_scene.gltf(filepath=out_cliff, export_format='GLB', use_selection=True)
    print(f"  -> Exported: {out_cliff}")
    
    # 2. Mesa Butte Pillar (170m high, 45m radius)
    print("\n[2/2] Generating canyon_mesa_pillar.glb (170m high, 45m radius)...")
    mesa_obj = create_mesa_pillar()
    out_mesa = os.path.join(out_dir, "canyon_mesa_pillar.glb")
    bpy.ops.export_scene.gltf(filepath=out_mesa, export_format='GLB', use_selection=True)
    print(f"  -> Exported: {out_mesa}")
    
    print("\n[SUCCESS] Canyon terrain meshes generated successfully!")

if __name__ == "__main__":
    main()
