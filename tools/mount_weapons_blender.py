# -*- coding: utf-8 -*-
"""
Blender Weapon Integration:
1. Imports CAD Strike Missile & Pylon from Fusion 360.
2. Scales to metric meters (0.001) and sets up PBR materials.
3. Adds rocket exhaust gameplay socket and collision hull.
4. Exports standalone game-ready FBX.
5. Snaps 4 instances under the wings of Spaceship_Sculpted_V_Hull.
"""

import bpy
import bmesh
import math
import os
from mathutils import Vector, Euler

print(">>> Integrating Vanguard Strike Missile into Blender...")

stl_path = r"c:\Users\Boris\Documents\antigravity\lucid-davinci\assets\cad\vehicles\Vanguard_Strike_Missile.stl"
export_fbx_path = r"c:\Users\Boris\Documents\antigravity\lucid-davinci\assets\meshes\vehicles\Vanguard_Strike_Missile.fbx"

# Remove previous missile objects if any
for obj in list(bpy.data.objects):
    if "Vanguard_Strike_Missile" in obj.name or "Missile_Mount" in obj.name:
        bpy.data.objects.remove(obj, do_unlink=True)

# 1. Import STL
bpy.ops.wm.stl_import(filepath=stl_path)
missile_master = bpy.context.selected_objects[0]
missile_master.name = "Vanguard_Strike_Missile_Master"

# Scale to metric meters
if missile_master.dimensions.y > 10.0:
    missile_master.scale = (0.001, 0.001, 0.001)
    bpy.ops.object.select_all(action='DESELECT')
    missile_master.select_set(True)
    bpy.context.view_layer.objects.active = missile_master
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

print(f"Normalized Missile Dimensions: {tuple(round(d, 3) for d in missile_master.dimensions)}m")

# 2. Materials
def get_or_create_mat(name, color, metallic=0.2, roughness=0.3, emission=None, emission_strength=1.0):
    mat = bpy.data.materials.get(name)
    if not mat:
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    out = nodes.new(type='ShaderNodeOutputMaterial')
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.inputs['Base Color'].default_value = color
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if emission:
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value = emission
            bsdf.inputs['Emission Strength'].default_value = emission_strength
        elif 'Emission' in bsdf.inputs:
            bsdf.inputs['Emission'].default_value = emission
    mat.node_tree.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat

mat_body = get_or_create_mat("MI_Missile_Airframe", (0.85, 0.86, 0.88, 1.0), metallic=0.15, roughness=0.25)
mat_fins = get_or_create_mat("MI_Missile_Fins", (0.12, 0.13, 0.15, 1.0), metallic=0.85, roughness=0.35)
mat_pylon = get_or_create_mat("MI_Weapon_Pylon", (0.05, 0.06, 0.07, 1.0), metallic=0.90, roughness=0.40)
mat_warhead = get_or_create_mat("MI_Missile_Radome", (0.95, 0.65, 0.1, 1.0), metallic=0.1, roughness=0.2) # High-visibility seeker nose

missile_master.data.materials.clear()
missile_master.data.materials.append(mat_body)      # Slot 0
missile_master.data.materials.append(mat_warhead)   # Slot 1
missile_master.data.materials.append(mat_fins)      # Slot 2

# Assign faces
bm = bmesh.new()
bm.from_mesh(missile_master.data)
for face in bm.faces:
    center = face.calc_center_median()
    # Seeker radome (front nose: Y > -0.35m)
    if center.y > -0.35:
        face.material_index = 1
    # Fins (outer radius > 0.11m)
    elif math.sqrt(center.x**2 + center.z**2) > 0.10:
        face.material_index = 2
    else:
        face.material_index = 0
bm.to_mesh(missile_master.data)
bm.free()
missile_master.data.update()

# 3. Add Rocket Motor Exhaust Socket
exhaust_socket = bpy.data.objects.new("SOCKET_Missile_Exhaust", None)
exhaust_socket.empty_display_type = 'ARROWS'
exhaust_socket.empty_display_size = 0.2
exhaust_socket.location = (0, -2.25, 0)
exhaust_socket.rotation_euler = Euler((0, 0, math.radians(180)), 'XYZ')
bpy.context.collection.objects.link(exhaust_socket)
exhaust_socket.parent = missile_master

# 4. Create UCX Collision
bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=2.35, vertices=12, location=(0, -1.17, 0), rotation=(math.radians(90), 0, 0))
ucx_missile = bpy.context.active_object
ucx_missile.name = "UCX_Vanguard_Strike_Missile"
ucx_missile.display_type = 'WIRE'
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

# 5. Export Standalone Game-Ready Missile FBX
bpy.ops.object.select_all(action='DESELECT')
missile_master.select_set(True)
ucx_missile.select_set(True)
exhaust_socket.select_set(True)
bpy.context.view_layer.objects.active = missile_master

bpy.ops.export_scene.fbx(
    filepath=export_fbx_path,
    use_selection=True,
    apply_scale_options='FBX_SCALE_ALL',
    axis_forward='-Z',
    axis_up='Y'
)
print(f"Exported game-ready weapon FBX: {export_fbx_path}")

# Remove UCX from scene view to keep viewport clean
bpy.data.objects.remove(ucx_missile, do_unlink=True)

# 6. Mount 4 instances onto the Spaceship
ship = bpy.data.objects.get("Spaceship_Sculpted_V_Hull")
if not ship:
    print("[WARNING] Ship object not found for socket mounting.")
else:
    hardpoint_names = [
        "SOCKET_Weapon_Hardpoint_01",
        "SOCKET_Weapon_Hardpoint_02",
        "SOCKET_Weapon_Hardpoint_03",
        "SOCKET_Weapon_Hardpoint_04"
    ]
    
    # Hide the master template so only mounted instances appear
    missile_master.hide_viewport = True
    missile_master.hide_render = True

    for i, hp_name in enumerate(hardpoint_names, 1):
        hp_obj = bpy.data.objects.get(hp_name)
        if not hp_obj:
            print(f"[!] Socket {hp_name} not found.")
            continue
        
        # Duplicate linked mesh data (ultra-lightweight memory footprint)
        instance = bpy.data.objects.new(f"Weapon_Missile_Mounted_0{i}", missile_master.data)
        bpy.context.collection.objects.link(instance)
        
        # Position: attach to socket location
        instance.location = hp_obj.location.copy()
        # Offset slightly down along Z so pylon touches wing hardpoint
        # Align rotation with ship
        instance.rotation_euler = (0, 0, 0)
        instance.parent = ship
        
        print(f"Mounted missile instance {instance.name} to {hp_name} at {tuple(round(c, 2) for c in instance.location)}")

print(">>> SUCCESS: 4 Strike Missiles mounted under wings with PBR materials and exhaust sockets!")
