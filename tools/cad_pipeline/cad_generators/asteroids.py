# -*- coding: utf-8 -*-
"""
Asteroid and Mine CAD/Procedural Generators.
Generates:
1. asteroid_boulder_medium (28m diameter boulder, 2.5k - 6k tris)
2. asteroid_cluster_large (120m x 85m x 90m fractured cluster, 8k - 18k tris)
3. asteroid_tether_mine (3.2m tip-to-tip proximity tether mine, 2k - 4k tris)
"""

import math
import random
import bpy
import bmesh
from mathutils import Vector
from ..config import ASSET_CONFIGS
from ..polishing.materials import setup_asset_materials, get_or_create_material
from ..polishing.sockets import create_sockets
from ..polishing.collision import generate_collision_hulls
from ..polishing.hard_surface import apply_hard_surface_polishing


def build_asteroid_boulder(config=None):
    """
    Generates the asteroid_boulder_medium asset.
    """
    if config is None:
        config = ASSET_CONFIGS["asteroid_boulder_medium"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # Subdivided IcoSphere (subdivisions=5 -> 5,120 triangles, budget 2.5k - 6k)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=14.0)
    ast = bpy.context.active_object
    ast.name = "asteroid_boulder_medium"
    root = ast

    random.seed(42)
    mesh = ast.data
    for v in mesh.vertices:
        p = v.co
        n1 = math.sin(p.x * 0.35) * math.cos(p.y * 0.35) * math.sin(p.z * 0.35)
        n2 = math.cos(p.x * 0.9 + 1.2) * math.sin(p.z * 0.9)
        n3 = math.sin(p.y * 1.8) * math.cos(p.x * 1.8) * 0.5
        factor = 1.0 + (n1 * 0.22 + n2 * 0.14 + n3 * 0.08) * 0.35
        v.co = p * factor

    mesh.update()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    setup_asset_materials(root, config["materials"])
    create_sockets(root, config["sockets"], display_size=2.0)
    generate_collision_hulls(config["name"], root, config.get("collision_parts"))

    return root


def build_asteroid_cluster(config=None):
    """
    Generates the asteroid_cluster_large asset (120m x 85m x 90m composite cluster).
    """
    if config is None:
        config = ASSET_CONFIGS["asteroid_cluster_large"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # Primary core rocky mass (subdivisions=5 -> 5,120 triangles)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=38.0)
    core = bpy.context.active_object
    core.name = "asteroid_cluster_large"
    core.scale = (0.75, 1.25, 0.82) # Fits ~85m x 120m x 90m
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    root = core

    setup_asset_materials(root, config["materials"])
    mat_rock = get_or_create_material("MI_Asteroid_Rock")

    # Intersecting fractured boulder masses (5 chunks x 1,280 = 6,400 -> total ~11,520 tris)
    cluster_boulders = [
        ((22.0, 26.0, 18.0), 19.0, (0.8, 1.2, 0.9)),
        ((-21.0, -31.0, -16.0), 23.0, (1.1, 0.9, 1.2)),
        ((16.0, -39.0, 13.0), 16.0, (0.9, 1.0, 1.1)),
        ((-25.0, 31.0, -11.0), 17.5, (1.2, 0.8, 1.0)),
        ((0.0, 0.0, 28.0), 14.0, (1.0, 1.0, 0.8)),
    ]

    for idx, (b_loc, b_rad, b_sc) in enumerate(cluster_boulders, start=1):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=b_rad, location=b_loc)
        boulder = bpy.context.active_object
        boulder.name = f"Cluster_Chunk_{idx:02d}"
        boulder.scale = b_sc
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        boulder.data.materials.append(mat_rock)
        boulder.parent = root

    # Procedural rocky crag displacement across all chunks
    random.seed(99)
    for obj in [root] + list(root.children):
        if obj.type == 'MESH':
            for v in obj.data.vertices:
                p = v.co
                d1 = math.sin(p.x * 0.15) * math.cos(p.y * 0.15)
                d2 = math.cos(p.z * 0.25) * 0.5
                v.co = p * (1.0 + (d1 + d2) * 0.18)
            obj.data.update()

    create_sockets(root, config["sockets"], display_size=10.0)
    generate_collision_hulls(config["name"], root, config.get("collision_parts"))

    return root


def build_tether_mine(config=None):
    """
    Generates the asteroid_tether_mine asset (3.20m tip-to-tip Combine proximity mine).
    """
    if config is None:
        config = ASSET_CONFIGS["asteroid_tether_mine"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Spherical metallic hull (Diameter 1.80m -> Radius 0.90m)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=24, radius=0.90, location=(0, 0, 0))
    mine_hull = bpy.context.active_object
    mine_hull.name = "asteroid_tether_mine"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    root = mine_hull

    setup_asset_materials(root, config["materials"])
    mat_metal = get_or_create_material("MI_Mine_Metal")
    mat_glow = get_or_create_material("MI_Mine_Core_Glow")

    # 2. Glowing sensor equator band
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.92,
        minor_radius=0.08,
        major_segments=32,
        minor_segments=16,
        location=(0, 0, 0)
    )
    torus = bpy.context.active_object
    torus.name = "Mine_Sensor_Band"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    torus.data.materials.append(mat_glow)
    torus.parent = root

    # 3. Six magnetic sensor spikes (extending to 1.60m from center -> 3.20m tip-to-tip)
    spikes_def = [
        ((1.25, 0, 0), (0, math.radians(90), 0)),
        ((-1.25, 0, 0), (0, math.radians(-90), 0)),
        ((0, 1.25, 0), (math.radians(-90), 0, 0)),
        ((0, -1.25, 0), (math.radians(90), 0, 0)),
        ((0, 0, 1.25), (0, 0, 0)),
        ((0, 0, -1.25), (math.radians(180), 0, 0)),
    ]
    for idx, (s_loc, s_rot) in enumerate(spikes_def, start=1):
        bpy.ops.mesh.primitive_cone_add(
            vertices=16,
            radius1=0.18,
            radius2=0.03,
            depth=0.70,
            location=s_loc,
            rotation=s_rot
        )
        spike = bpy.context.active_object
        spike.name = f"Proximity_Spike_{idx:02d}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        spike.data.materials.append(mat_metal)
        spike.parent = root

    # Clean degenerate faces
    for obj in [root] + list(root.children):
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

    apply_hard_surface_polishing(root, bevel_width=0.01, bevel_segments=1)
    create_sockets(root, config["sockets"])
    generate_collision_hulls(config["name"], root, config.get("collision_parts"))

    return root
