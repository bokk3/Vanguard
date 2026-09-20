# -*- coding: utf-8 -*-
"""
Chapter 2 Procedural 3D Asset Generator for Project Vanguard (Blender 4.2+).
Builds complete game-ready GLBs for:
1. Asteroids & Mines:
   - asteroid_boulder_medium.glb (14m rocky asteroid)
   - asteroid_cluster_large.glb (70m monolithic asteroid)
   - asteroid_tether_mine.glb (4m spherical Combine tether-mine with warning spikes)
2. Cavern Infrastructure:
   - cavern_tunnel_ring.glb (140m structural excavation ring with steel ribs)
   - cavern_generator_core.glb (12m geothermal extraction generator with cyan plasma coils)
   - laser_sentry_turret.glb (automated wall-mounted defensive laser turret)
3. Capital Fleet & Dreadnought Boss:
   - carrier_soc_dauntless.glb (350m Directorate flagship carrier with angled flight deck)
   - dreadnought_nemesis9.glb (280m Helion Ironclad Dreadnought with forward railgun & flak pods)
   - heavy_anti_ship_torpedo.glb (8m high-velocity fusion torpedo)
"""

import bpy
import bmesh
import math
import os
import random

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

OUTPUT_VEHICLES = os.path.abspath("godot_project/assets/meshes/vehicles")
OUTPUT_ENV = os.path.abspath("godot_project/assets/meshes/environment")
ensure_dir(OUTPUT_VEHICLES)
ensure_dir(OUTPUT_ENV)

def create_pbr_material(name, color, metallic=0.0, roughness=0.5, emission=None, emission_strength=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (*color, 1.0) if len(color) == 3 else color
        bsdf.inputs['Metallic'].default_value = metallic
        bsdf.inputs['Roughness'].default_value = roughness
        if emission:
            if 'Emission Color' in bsdf.inputs:
                bsdf.inputs['Emission Color'].default_value = (*emission, 1.0) if len(emission) == 3 else emission
                bsdf.inputs['Emission Strength'].default_value = emission_strength
    return mat

# =============================================================================
# 1. ASTEROID & TETHER-MINE ASSETS
# =============================================================================

def build_asteroid(radius, filename, subdivisions=3, noise_scale=0.35, roughness=0.85):
    clear_scene()
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius)
    ast = bpy.context.active_object
    ast.name = "Asteroid"
    
    # Displace vertices with procedural pseudo-noise
    random.seed(int(radius * 42))
    mesh = ast.data
    for v in mesh.vertices:
        p = v.co
        dist = p.length
        # Multiscale spherical harmonics approximation
        n1 = math.sin(p.x * 0.4) * math.cos(p.y * 0.4) * math.sin(p.z * 0.4)
        n2 = math.cos(p.x * 1.1 + 1.2) * math.sin(p.z * 1.1)
        n3 = math.sin(p.y * 2.3) * math.cos(p.x * 2.3) * 0.5
        factor = 1.0 + (n1 * 0.25 + n2 * 0.15 + n3 * 0.08) * noise_scale
        v.co = p * factor
    
    mesh.update()
    bpy.ops.object.shade_smooth()
    
    # Material
    mat_rock = create_pbr_material("Mat_AsteroidRock", (0.18, 0.16, 0.15), metallic=0.25, roughness=roughness)
    ast.data.materials.append(mat_rock)
    
    out_file = os.path.join(OUTPUT_ENV, filename)
    bpy.ops.export_scene.gltf(filepath=out_file, export_format='GLB')
    print(f"Exported: {out_file}")

def build_tether_mine():
    clear_scene()
    # Spherical hull
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.8, segments=24, ring_count=16)
    hull = bpy.context.active_object
    hull.name = "MineHull"
    
    mat_mine = create_pbr_material("Mat_MineMetal", (0.12, 0.12, 0.14), metallic=0.9, roughness=0.28)
    mat_glow = create_pbr_material("Mat_MineCore", (1.0, 0.4, 0.0), metallic=0.1, roughness=0.2, emission=(1.0, 0.45, 0.0), emission_strength=5.0)
    hull.data.materials.append(mat_mine)
    
    # 6 Proximity Spikes
    spikes = [
        (Vector3 if 'Vector3' in globals() else None, (2.8, 0, 0), (0, 1.5708, 0)),
        (None, (-2.8, 0, 0), (0, -1.5708, 0)),
        (None, (0, 2.8, 0), (-1.5708, 0, 0)),
        (None, (0, -2.8, 0), (1.5708, 0, 0)),
        (None, (0, 0, 2.8), (0, 0, 0)),
        (None, (0, 0, -2.8), (3.1415, 0, 0))
    ]
    for _, loc, rot in spikes:
        bpy.ops.mesh.primitive_cone_add(radius1=0.25, radius2=0.04, depth=2.4, location=loc, rotation=rot)
        spike = bpy.context.active_object
        spike.data.materials.append(mat_mine)
        spike.parent = hull
        
    # Glowing sensor bands
    bpy.ops.mesh.primitive_torus_add(major_radius=1.85, minor_radius=0.12, location=(0,0,0))
    torus = bpy.context.active_object
    torus.data.materials.append(mat_glow)
    torus.parent = hull
    
    out_file = os.path.join(OUTPUT_ENV, "asteroid_tether_mine.glb")
    bpy.ops.export_scene.gltf(filepath=out_file, export_format='GLB')
    print(f"Exported: {out_file}")

# =============================================================================
# 2. MINING CAVERN & SENTRY ASSETS
# =============================================================================

def build_cavern_tunnel_ring():
    clear_scene()
    # Hexagonal / Octagonal Rock Chamber Ring (Inner diameter ~140m, depth 80m)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=70.0, depth=80.0, end_fill_type='NOTHING')
    ring = bpy.context.active_object
    ring.name = "CavernRing"
    
    # Invert normals to make inside surface visible
    bm = bmesh.new()
    bm.from_mesh(ring.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    
    # Add random displacement to rock faces
    random.seed(99)
    for v in bm.verts:
        v.co.x += (random.random() - 0.5) * 8.0
        v.co.y += (random.random() - 0.5) * 8.0
    bm.to_mesh(ring.data)
    bm.free()
    
    mat_rock = create_pbr_material("Mat_CavernRock", (0.15, 0.13, 0.12), metallic=0.3, roughness=0.9)
    ring.data.materials.append(mat_rock)
    
    # Add structural industrial steel ring ribs
    mat_steel = create_pbr_material("Mat_CavernSteel", (0.28, 0.30, 0.35), metallic=0.85, roughness=0.35)
    for z in [-30.0, 0.0, 30.0]:
        bpy.ops.mesh.primitive_torus_add(major_radius=68.5, minor_radius=1.2, major_segments=16, minor_segments=8, location=(0, 0, z))
        rib = bpy.context.active_object
        rib.data.materials.append(mat_steel)
        rib.parent = ring
        
    out_file = os.path.join(OUTPUT_ENV, "cavern_tunnel_straight.glb")
    bpy.ops.export_scene.gltf(filepath=out_file, export_format='GLB')
    print(f"Exported: {out_file}")

def build_cavern_generator_core():
    clear_scene()
    # Central geothermal generator base
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=6.0, depth=14.0)
    gen = bpy.context.active_object
    gen.name = "GeneratorCore"
    
    mat_metal = create_pbr_material("Mat_GenArmor", (0.18, 0.20, 0.22), metallic=0.9, roughness=0.3)
    mat_plasma = create_pbr_material("Mat_GenPlasma", (0.0, 0.9, 1.0), metallic=0.0, roughness=0.1, emission=(0.0, 0.95, 1.0), emission_strength=7.0)
    gen.data.materials.append(mat_metal)
    
    # Glowing plasma containment rings
    for z in [-4.0, 0.0, 4.0]:
        bpy.ops.mesh.primitive_torus_add(major_radius=6.4, minor_radius=0.6, location=(0, 0, z))
        ring = bpy.context.active_object
        ring.data.materials.append(mat_plasma)
        ring.parent = gen
        
    # Cooling heat-sinks
    for angle in [0, 90, 180, 270]:
        rad = math.radians(angle)
        loc = (math.cos(rad) * 7.5, math.sin(rad) * 7.5, 0)
        bpy.ops.mesh.primitive_cube_add(size=2.0, scale=(1.2, 0.4, 6.0), location=loc)
        fin = bpy.context.active_object
        fin.rotation_euler.z = rad
        fin.data.materials.append(mat_metal)
        fin.parent = gen
        
    out_file = os.path.join(OUTPUT_ENV, "cavern_generator_core.glb")
    bpy.ops.export_scene.gltf(filepath=out_file, export_format='GLB')
    print(f"Exported: {out_file}")

def build_laser_sentry_turret():
    clear_scene()
    # Mount base
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=2.5, depth=0.8)
    base = bpy.context.active_object
    base.name = "LaserSentry"
    
    mat_turret = create_pbr_material("Mat_TurretDark", (0.1, 0.1, 0.12), metallic=0.88, roughness=0.32)
    mat_laser = create_pbr_material("Mat_LaserOptic", (1.0, 0.1, 0.2), metallic=0.0, roughness=0.1, emission=(1.0, 0.15, 0.2), emission_strength=8.0)
    base.data.materials.append(mat_turret)
    
    # Swivel ball
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.8, location=(0, 0, 1.4))
    ball = bpy.context.active_object
    ball.data.materials.append(mat_turret)
    ball.parent = base
    
    # Dual laser emitters
    for y in [-0.6, 0.6]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.25, depth=3.0, location=(1.8, y, 1.4), rotation=(0, 1.5708, 0))
        barrel = bpy.context.active_object
        barrel.data.materials.append(mat_turret)
        barrel.parent = ball
        
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(3.3, y, 1.4))
        lens = bpy.context.active_object
        lens.data.materials.append(mat_laser)
        lens.parent = barrel
        
    out_file = os.path.join(OUTPUT_ENV, "laser_sentry_turret.glb")
    bpy.ops.export_scene.gltf(filepath=out_file, export_format='GLB')
    print(f"Exported: {out_file}")

# =============================================================================
# 3. CAPITAL CARRIER, DREADNOUGHT BOSS, & TORPEDO
# =============================================================================

def build_carrier_soc_dauntless():
    clear_scene()
    # 350m Directorate Carrier
    # Main Hull block
    bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(60.0, 320.0, 36.0), location=(0, 0, 0))
    hull = bpy.context.active_object
    hull.name = "CarrierHull"
    
    mat_dir_hull = create_pbr_material("Mat_CarrierHull", (0.16, 0.22, 0.30), metallic=0.88, roughness=0.28)
    mat_deck = create_pbr_material("Mat_CarrierDeck", (0.08, 0.10, 0.14), metallic=0.75, roughness=0.5)
    mat_gold = create_pbr_material("Mat_DirectorateTrim", (0.95, 0.68, 0.12), metallic=0.85, roughness=0.25)
    mat_engine = create_pbr_material("Mat_CarrierDrive", (0.1, 0.8, 1.0), metallic=0.0, roughness=0.1, emission=(0.15, 0.85, 1.0), emission_strength=7.0)
    
    hull.data.materials.append(mat_dir_hull)
    
    # Angled Flight Deck Plate (Upper surface)
    bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(72.0, 280.0, 4.0), location=(0, 20.0, 20.0))
    deck = bpy.context.active_object
    deck.data.materials.append(mat_deck)
    deck.parent = hull
    
    # Island / Command Tower (Starboard side)
    bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(16.0, 40.0, 32.0), location=(38.0, 40.0, 34.0))
    tower = bpy.context.active_object
    tower.data.materials.append(mat_dir_hull)
    tower.parent = hull
    
    # Sensor dome on top of island
    bpy.ops.mesh.primitive_uv_sphere_add(radius=8.0, location=(38.0, 40.0, 52.0))
    radome = bpy.context.active_object
    radome.data.materials.append(mat_gold)
    radome.parent = tower
    
    # Dual Engine Thruster Banks
    for x in [-22.0, 22.0]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=12.0, depth=30.0, location=(x, -165.0, 0), rotation=(1.5708, 0, 0))
        eng = bpy.context.active_object
        eng.data.materials.append(mat_dir_hull)
        eng.parent = hull
        
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=9.5, depth=4.0, location=(x, -178.0, 0), rotation=(1.5708, 0, 0))
        plume = bpy.context.active_object
        plume.data.materials.append(mat_engine)
        plume.parent = eng
        
    out_file = os.path.join(OUTPUT_VEHICLES, "carrier_soc_dauntless.glb")
    bpy.ops.export_scene.gltf(filepath=out_file, export_format='GLB')
    print(f"Exported: {out_file}")

def build_dreadnought_nemesis9():
    clear_scene()
    # 280m Helion Heavy Dreadnought
    # Angular, menacing dagger profile
    bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(70.0, 260.0, 38.0), location=(0, 0, 0))
    dread = bpy.context.active_object
    dread.name = "DreadnoughtNemesis9"
    
    mat_dark_armor = create_pbr_material("Mat_HelionArmor", (0.10, 0.10, 0.12), metallic=0.92, roughness=0.22)
    mat_crimson = create_pbr_material("Mat_HelionCrimson", (0.85, 0.05, 0.08), metallic=0.8, roughness=0.3)
    mat_crimson_glow = create_pbr_material("Mat_HelionCoreGlow", (1.0, 0.1, 0.15), metallic=0.0, roughness=0.1, emission=(1.0, 0.12, 0.18), emission_strength=7.0)
    mat_shields = create_pbr_material("Mat_ShieldDome", (0.1, 0.5, 1.0), metallic=0.1, roughness=0.2, emission=(0.15, 0.6, 1.0), emission_strength=5.0)
    
    dread.data.materials.append(mat_dark_armor)
    
    # Forward Heavy Railgun Prow
    bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(24.0, 110.0, 18.0), location=(0, 150.0, 0))
    prow = bpy.context.active_object
    prow.data.materials.append(mat_dark_armor)
    prow.parent = dread
    
    # Railgun twin guide-rails
    for x in [-8.0, 8.0]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(4.0, 120.0, 6.0), location=(x, 160.0, 2.0))
        rail = bpy.context.active_object
        rail.data.materials.append(mat_crimson)
        rail.parent = prow
        
    # Exposed Fusion Reactor Core (Ventral Trench)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=14.0, depth=45.0, location=(0, -20.0, -18.0), rotation=(1.5708, 0, 0))
    core = bpy.context.active_object
    core.data.materials.append(mat_crimson_glow)
    core.parent = dread
    
    # 4x Heavy Rotary Flak Pods
    flak_locs = [(-32.0, 40.0, 22.0), (32.0, 40.0, 22.0), (-32.0, -50.0, 22.0), (32.0, -50.0, 22.0)]
    for loc in flak_locs:
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=7.0, depth=8.0, location=loc)
        flak = bpy.context.active_object
        flak.data.materials.append(mat_crimson)
        flak.parent = dread
        
    # Twin Ventral Shield Generator Domes
    for x in [-28.0, 28.0]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=9.0, location=(x, 0.0, -20.0))
        sdome = bpy.context.active_object
        sdome.data.materials.append(mat_shields)
        sdome.parent = dread
        
    out_file = os.path.join(OUTPUT_VEHICLES, "dreadnought_nemesis9.glb")
    bpy.ops.export_scene.gltf(filepath=out_file, export_format='GLB')
    print(f"Exported: {out_file}")

def build_heavy_torpedo():
    clear_scene()
    # 8m Anti-Ship Torpedo
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.9, depth=7.0, rotation=(1.5708, 0, 0))
    body = bpy.context.active_object
    body.name = "HeavyTorpedo"
    
    mat_torp = create_pbr_material("Mat_TorpCasing", (0.12, 0.12, 0.15), metallic=0.92, roughness=0.28)
    mat_warhead = create_pbr_material("Mat_TorpWarhead", (0.9, 0.08, 0.08), metallic=0.8, roughness=0.3)
    mat_drive = create_pbr_material("Mat_TorpDrive", (1.0, 0.3, 0.0), metallic=0.0, roughness=0.1, emission=(1.0, 0.35, 0.0), emission_strength=8.0)
    
    body.data.materials.append(mat_torp)
    
    # Warhead Cone
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.9, radius2=0.05, depth=2.2, location=(0, 4.4, 0), rotation=(-1.5708, 0, 0))
    nose = bpy.context.active_object
    nose.data.materials.append(mat_warhead)
    nose.parent = body
    
    # 4 Stabilizing Fin Wings
    for angle in [0, 90, 180, 270]:
        rad = math.radians(angle)
        bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(0.1, 1.8, 1.4), location=(math.cos(rad) * 1.3, -2.6, math.sin(rad) * 1.3))
        fin = bpy.context.active_object
        fin.rotation_euler.y = rad
        fin.data.materials.append(mat_torp)
        fin.parent = body
        
    # Drive Nozzle & Plume
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.65, depth=0.8, location=(0, -3.8, 0), rotation=(1.5708, 0, 0))
    glow = bpy.context.active_object
    glow.data.materials.append(mat_drive)
    glow.parent = body
    
    out_file = os.path.join(OUTPUT_VEHICLES, "heavy_anti_ship_torpedo.glb")
    bpy.ops.export_scene.gltf(filepath=out_file, export_format='GLB')
    print(f"Exported: {out_file}")

# =============================================================================
# MAIN BATCH EXECUTION
# =============================================================================
def main():
    print("--- BUILDING CHAPTER 2 PROCEDURAL 3D ASSETS ---")
    # Asteroids & Mines
    build_asteroid(14.0, "asteroid_boulder_medium.glb", subdivisions=3, noise_scale=0.35)
    build_asteroid(70.0, "asteroid_cluster_large.glb", subdivisions=4, noise_scale=0.45)
    build_tether_mine()
    
    # Cavern Assets
    build_cavern_tunnel_ring()
    build_cavern_generator_core()
    build_laser_sentry_turret()
    
    # Fleet Assets
    build_carrier_soc_dauntless()
    build_dreadnought_nemesis9()
    build_heavy_torpedo()
    print("--- ALL CHAPTER 2 3D ASSETS EXPORTED SUCCESSFULLY ---")

if __name__ == "__main__":
    main()
