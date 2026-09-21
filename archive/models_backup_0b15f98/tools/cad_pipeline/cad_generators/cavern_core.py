# -*- coding: utf-8 -*-
"""
Cavern Geothermal Generator Core CAD Generator.
Builds the 16.0m x 16.0m x 24.0m Octagonal geothermal power core
with 8.0m core diameter, coolant conduit ports, and glowing plasma containment coils.
Dimensions: Total Frame: 16.0m x 16.0m x 24.0m, Core Diameter: 8.0m.
Polycount target: 6,000 - 10,000 triangles.
"""

import math
import bpy
import bmesh
from mathutils import Vector
from ..config import ASSET_CONFIGS
from ..polishing.materials import setup_asset_materials, get_or_create_material
from ..polishing.sockets import create_sockets
from ..polishing.collision import generate_collision_hulls
from ..polishing.hard_surface import apply_hard_surface_polishing


def build_cavern_generator_core(config=None):
    """
    Generates the cavern_generator_core environment interactive prop.
    """
    if config is None:
        config = ASSET_CONFIGS["cavern_generator_core"]

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Central Cylindrical Core (Core Diameter 8.0m -> Radius 4.0m, Height 22.0m)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=40,
        radius=4.0,
        depth=22.0,
        location=(0.0, 0.0, 0.0)
    )
    core = bpy.context.active_object
    core.name = "cavern_generator_core"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    root = core

    setup_asset_materials(root, config["materials"])
    mat_struct = get_or_create_material("MI_Generator_Structure")
    mat_plasma = get_or_create_material("MI_Plasma_Coil_Glow")
    mat_pipe = get_or_create_material("MI_Coolant_Conduit")

    # 2. Octagonal Outer Structural Frame (16.0m x 16.0m x 24.0m, Radius 8.0m, Fully Closed Solid)
    # Using closed solid cylinder ensures Wireframe produces 100% manifold structural struts
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=7.8,
        depth=23.8,
        location=(0.0, 0.0, 0.0),
        end_fill_type='NGON'
    )
    frame = bpy.context.active_object
    frame.name = "Generator_Octagonal_Frame"
    wire_mod = frame.modifiers.new(name="CAD_FrameWire", type='WIREFRAME')
    wire_mod.thickness = 0.40
    bpy.context.view_layer.objects.active = frame
    frame.select_set(True)
    bpy.ops.object.modifier_apply(modifier="CAD_FrameWire")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    frame.data.materials.append(mat_struct)
    frame.parent = root

    # 3. Glowing Plasma Containment Coils (4 torus rings around central core)
    for z_pos in [-7.5, -2.5, 2.5, 7.5]:
        bpy.ops.mesh.primitive_torus_add(
            major_radius=4.35,
            minor_radius=0.40,
            major_segments=48,
            minor_segments=20,
            location=(0.0, 0.0, z_pos)
        )
        coil = bpy.context.active_object
        coil.name = f"Plasma_Containment_Coil_{z_pos:+.1f}"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        coil.data.materials.append(mat_plasma)
        coil.parent = root

    # 4. Four Radial Coolant Conduit Pipes (Ports radiating out to X=±7.5m, Y=±7.5m)
    conduit_ports = [
        ("Coolant_Conduit_01", (5.8, 0.0, 0.0), (0, math.radians(90), 0)),
        ("Coolant_Conduit_02", (-5.8, 0.0, 0.0), (0, math.radians(-90), 0)),
        ("Coolant_Conduit_03", (0.0, 5.8, 0.0), (math.radians(-90), 0, 0)),
        ("Coolant_Conduit_04", (0.0, -5.8, 0.0), (math.radians(90), 0, 0)),
    ]
    for p_name, p_loc, p_rot in conduit_ports:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=28,
            radius=0.85,
            depth=4.2,
            location=p_loc,
            rotation=p_rot
        )
        conduit = bpy.context.active_object
        conduit.name = p_name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        conduit.data.materials.append(mat_pipe)
        conduit.parent = root

        # Port mounting flange
        f_loc = (p_loc[0] * 1.3, p_loc[1] * 1.3, p_loc[2])
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=28,
            radius=1.25,
            depth=0.50,
            location=f_loc,
            rotation=p_rot
        )
        flange = bpy.context.active_object
        flange.name = f"{p_name}_Flange"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        flange.data.materials.append(mat_struct)
        flange.parent = conduit

    # 5. Cooling Radiator Heat-Sink Fins (8 fins around circumference)
    for i in range(8):
        rad = math.radians(i * 45)
        fx = math.cos(rad) * 4.9
        fy = math.sin(rad) * 4.9
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(fx, fy, 0.0)
        )
        fin = bpy.context.active_object
        fin.name = f"Radiator_Fin_{i:02d}"
        fin.scale = (0.25, 1.8, 16.0)
        fin.rotation_euler.z = rad
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        fin.data.materials.append(mat_struct)
        fin.parent = root

    # Clean degenerate faces across all meshes
    for obj in [root] + list(root.children_recursive):
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

    # Hard-surface bevel & normals
    apply_hard_surface_polishing(root, bevel_width=0.02, bevel_segments=1)

    # Sockets setup
    create_sockets(root, config["sockets"], display_size=1.0)

    # Collision hulls setup
    generate_collision_hulls(config["name"], root, config.get("collision_parts"))

    return root
