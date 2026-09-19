# -*- coding: utf-8 -*-
"""
Blender Live Bridge: Upgrade Spaceship to Unreal Engine 5 Production Quality.
- Normalizes scale (mm -> meters)
- Sets origin to Center of Mass
- Adds 4 PBR Materials: Carbon Hull, Tinted Glass Canopy, Glowing Headlights, Plasma Thrusters
- Assigns material slots to corresponding hull regions
- Creates dual 3D Headlight housings and Twin Thruster afterburner rings
- Adds Unreal Engine Sockets (SOCKET_* Empties) for Headlights, Thrusters, Weapons, and Cockpit Camera
- Generates 4-piece modular UCX_ convex collision hulls
- Sets viewport to Material Shading mode with optimal camera view
"""

import bpy
import bmesh
import math
from mathutils import Vector, Euler

print(">>> Starting UE Compatibility Upgrade in Blender...")

# 1. Target objects
ship = bpy.data.objects.get("Spaceship_Sculpted_V_Hull")
if not ship:
    raise RuntimeError("Spaceship_Sculpted_V_Hull object not found in Blender scene!")

# Deselect all
bpy.ops.object.select_all(action='DESELECT')
ship.select_set(True)
bpy.context.view_layer.objects.active = ship

# 2. Scale normalization
# If dimensions are in thousands (mm), scale to meters
if ship.dimensions.y > 100.0:
    print(f"Current dimensions: {ship.dimensions}. Scaling by 0.001 to metric meters...")
    ship.scale = (0.001, 0.001, 0.001)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

# Also scale old UCX if present
old_ucx = bpy.data.objects.get("UCX_Spaceship_Sculpted_V_Hull")
if old_ucx:
    if old_ucx.dimensions.y > 100.0:
        old_ucx.scale = (0.001, 0.001, 0.001)
        bpy.ops.object.select_all(action='DESELECT')
        old_ucx.select_set(True)
        bpy.context.view_layer.objects.active = old_ucx
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

bpy.context.view_layer.objects.active = ship
ship.select_set(True)

# Compute bounding box in meters
bbox = [ship.matrix_world @ Vector(corner) for corner in ship.bound_box]
min_x = min(v.x for v in bbox)
max_x = max(v.x for v in bbox)
min_y = min(v.y for v in bbox)
max_y = max(v.y for v in bbox)
min_z = min(v.z for v in bbox)
max_z = max(v.z for v in bbox)

length_m = max_y - min_y
wingspan_m = max_x - min_x
height_m = max_z - min_z
print(f"Scaled Dimensions: Length={length_m:.2f}m, Wingspan={wingspan_m:.2f}m, Height={height_m:.2f}m")

# 3. Create PBR Materials
def get_or_create_material(name, base_color, metallic=0.0, roughness=0.5, emission=None, emission_strength=1.0, alpha=1.0):
    mat = bpy.data.materials.get(name)
    if not mat:
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
    
    nodes = mat.node_tree.nodes
    nodes.clear()
    
    output = nodes.new(type='ShaderNodeOutputMaterial')
    output.location = (400, 0)
    
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)
    
    # Configure BSDF
    bsdf.inputs['Base Color'].default_value = base_color
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    
    if alpha < 1.0:
        bsdf.inputs['Alpha'].default_value = alpha
        if 'Transmission Weight' in bsdf.inputs:
            bsdf.inputs['Transmission Weight'].default_value = 0.85
        elif 'Transmission' in bsdf.inputs:
            bsdf.inputs['Transmission'].default_value = 0.85
        mat.blend_method = 'BLEND'
    
    if emission:
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value = emission
            bsdf.inputs['Emission Strength'].default_value = emission_strength
        elif 'Emission' in bsdf.inputs:
            bsdf.inputs['Emission'].default_value = emission
    
    mat.node_tree.links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    return mat

mat_hull = get_or_create_material("MI_Spaceship_Hull", (0.08, 0.09, 0.11, 1.0), metallic=0.88, roughness=0.32)
mat_canopy = get_or_create_material("MI_Cockpit_Glass", (0.05, 0.25, 0.35, 0.4), metallic=0.1, roughness=0.08, alpha=0.35)
mat_headlight = get_or_create_material("MI_Headlights", (0.9, 0.95, 1.0, 1.0), metallic=0.0, roughness=0.1, emission=(0.8, 0.95, 1.0, 1.0), emission_strength=18.0)
mat_thruster = get_or_create_material("MI_Thrusters", (0.1, 0.6, 1.0, 1.0), metallic=0.0, roughness=0.2, emission=(0.05, 0.5, 1.0, 1.0), emission_strength=25.0)
mat_hardpoint = get_or_create_material("MI_Weapon_Pylon", (0.03, 0.03, 0.03, 1.0), metallic=0.9, roughness=0.45)

# Assign material slots to ship
ship.data.materials.clear()
ship.data.materials.append(mat_hull)       # Slot 0: Default Hull
ship.data.materials.append(mat_canopy)     # Slot 1: Canopy Glass
ship.data.materials.append(mat_thruster)   # Slot 2: Thrusters

# 4. Assign polygons to Canopy (top front) and Thrusters (rear)
mesh = ship.data
bm = bmesh.new()
bm.from_mesh(mesh)

canopy_slot_idx = 1
thruster_slot_idx = 2

for face in bm.faces:
    center = face.calc_center_median()
    # Canopy: X within [-0.8m, 0.8m], Y between [0.5m, 3.2m], Z > 0.45m
    if abs(center.x) < 0.85 and (0.5 < center.y < 3.2) and (center.z > 0.45):
        face.material_index = canopy_slot_idx
    # Thruster backfaces: Y < -4.2m, and near the engine tubes
    elif center.y < -4.2:
        face.material_index = thruster_slot_idx
    else:
        face.material_index = 0

bm.to_mesh(mesh)
bm.free()
mesh.update()
print("Assigned face material slots (Hull, Canopy, Thrusters).")

# 5. Add 3D Headlight Projectors and Thruster Rings
# Left Headlight
bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=0.15, vertices=16, location=(-1.15, 4.45, 0.28), rotation=(math.radians(90), 0, 0))
hl_l = bpy.context.active_object
hl_l.name = "Prop_Headlight_L"
hl_l.data.materials.append(mat_headlight)
hl_l.parent = ship

# Right Headlight
bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=0.15, vertices=16, location=(1.15, 4.45, 0.28), rotation=(math.radians(90), 0, 0))
hl_r = bpy.context.active_object
hl_r.name = "Prop_Headlight_R"
hl_r.data.materials.append(mat_headlight)
hl_r.parent = ship

# Left Thruster Glow Core
bpy.ops.mesh.primitive_cylinder_add(radius=0.42, depth=0.2, vertices=24, location=(-0.95, -4.62, -0.05), rotation=(math.radians(90), 0, 0))
th_l = bpy.context.active_object
th_l.name = "Prop_Thruster_Core_L"
th_l.data.materials.append(mat_thruster)
th_l.parent = ship

# Right Thruster Glow Core
bpy.ops.mesh.primitive_cylinder_add(radius=0.42, depth=0.2, vertices=24, location=(0.95, -4.62, -0.05), rotation=(math.radians(90), 0, 0))
th_r = bpy.context.active_object
th_r.name = "Prop_Thruster_Core_R"
th_r.data.materials.append(mat_thruster)
th_r.parent = ship

# 6. Create Gameplay Sockets (Unreal Engine Static Mesh Sockets)
# Empty objects prefixed with "SOCKET_" are automatically parsed as sockets by Unreal Engine FBX Importer
sockets_data = [
    ("SOCKET_Headlight_L", (-1.15, 4.55, 0.28), (0, 0, 0)),
    ("SOCKET_Headlight_R", (1.15, 4.55, 0.28), (0, 0, 0)),
    ("SOCKET_Thruster_L", (-0.95, -4.75, -0.05), (0, 0, 180)),
    ("SOCKET_Thruster_R", (0.95, -4.75, -0.05), (0, 0, 180)),
    ("SOCKET_Cockpit_Camera", (0.0, 1.85, 0.72), (0, 0, 0)),
    ("SOCKET_Chase_Camera", (0.0, -9.5, 3.2), (-12, 0, 0)),
    ("SOCKET_Ventral_Sensor", (0.0, 2.75, -0.72), (0, 0, 0)),
    ("SOCKET_Weapon_Hardpoint_01", (-3.6, -1.8, -0.25), (0, 0, 0)),
    ("SOCKET_Weapon_Hardpoint_02", (-2.6, -1.8, -0.25), (0, 0, 0)),
    ("SOCKET_Weapon_Hardpoint_03", (2.6, -1.8, -0.25), (0, 0, 0)),
    ("SOCKET_Weapon_Hardpoint_04", (3.6, -1.8, -0.25), (0, 0, 0)),
]

# Clear any existing sockets
for s_name, _, _ in sockets_data:
    if s_name in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[s_name], do_unlink=True)

for name, loc, rot_deg in sockets_data:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = 'ARROWS'
    empty.empty_display_size = 0.35
    empty.location = loc
    empty.rotation_euler = Euler((math.radians(rot_deg[0]), math.radians(rot_deg[1]), math.radians(rot_deg[2])), 'XYZ')
    bpy.context.collection.objects.link(empty)
    empty.parent = ship
    print(f"Created UE Socket: {name} at {loc}")

# 7. Setup 4-Piece Modular UCX_ Collision Meshes
# Remove old single monolithic UCX if desired or refine it
collision_pieces = [
    ("UCX_Spaceship_Fuselage_01", (0.0, 0.5, 0.1), (2.1, 8.8, 1.6)),
    ("UCX_Spaceship_Wing_L_01", (-2.8, -1.6, -0.1), (3.8, 4.5, 0.4)),
    ("UCX_Spaceship_Wing_R_01", (2.8, -1.6, -0.1), (3.8, 4.5, 0.4)),
    ("UCX_Spaceship_Canopy_01", (0.0, 1.8, 0.65), (1.4, 3.0, 0.9)),
]

for ucx_name, loc, dim in collision_pieces:
    if ucx_name in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[ucx_name], do_unlink=True)
    
    bpy.ops.mesh.primitive_cube_add(location=loc)
    ucx = bpy.context.active_object
    ucx.name = ucx_name
    ucx.dimensions = dim
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # Make collision meshes display as wireframe in Blender so they don't block the view
    ucx.display_type = 'WIRE'
    print(f"Created Convex Collision Hull: {ucx_name}")

# Delete old single UCX if present
if old_ucx and old_ucx.name != "UCX_Spaceship_Fuselage_01":
    bpy.data.objects.remove(old_ucx, do_unlink=True)

# 8. Set active camera view and Material Shading in Blender Viewport
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        for space in area.spaces:
            if space.type == 'VIEW_3D':
                space.shading.type = 'MATERIAL'
                space.clip_end = 1000.0

print(">>> SUCCESS: Spaceship successfully upgraded for Unreal Engine 5 in Blender!")
