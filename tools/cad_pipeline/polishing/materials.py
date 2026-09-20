# -*- coding: utf-8 -*-
"""
PBR Material Separation and Slot Assignment.
Assigns discrete materials (MI_Spaceship_Hull, MI_Cockpit_Glass, MI_Thrusters, etc.)
with calibrated PBR parameters for Godot 4 and Unreal Engine 5.
"""

import bpy
from ..config import MATERIAL_PRESETS


def get_or_create_material(name, preset=None):
    """
    Retrieves or creates a Principled BSDF material configured with PBR values.
    """
    mat = bpy.data.materials.get(name)
    if not mat:
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True

    if not mat.use_nodes:
        mat.use_nodes = True

    nodes = mat.node_tree.nodes
    nodes.clear()

    output = nodes.new(type='ShaderNodeOutputMaterial')
    output.location = (400, 0)

    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)

    params = preset or MATERIAL_PRESETS.get(name, {})
    base_color = params.get("base_color", (0.2, 0.2, 0.2, 1.0))
    metallic = params.get("metallic", 0.0)
    roughness = params.get("roughness", 0.5)
    alpha = params.get("alpha", 1.0)
    transmission = params.get("transmission", 0.0)
    emission = params.get("emission", None)
    emission_strength = params.get("emission_strength", 1.0)

    bsdf.inputs['Base Color'].default_value = base_color
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness

    if alpha < 1.0 or transmission > 0.0:
        bsdf.inputs['Alpha'].default_value = alpha
        if 'Transmission Weight' in bsdf.inputs:
            bsdf.inputs['Transmission Weight'].default_value = transmission
        elif 'Transmission' in bsdf.inputs:
            bsdf.inputs['Transmission'].default_value = transmission
        mat.blend_method = 'BLEND'

    if emission:
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value = emission
            bsdf.inputs['Emission Strength'].default_value = emission_strength
        elif 'Emission' in bsdf.inputs:
            bsdf.inputs['Emission'].default_value = emission

    mat.node_tree.links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    return mat


def setup_asset_materials(mesh_obj, material_names):
    """
    Ensures all specified material slots exist on the mesh object in order.
    """
    if not mesh_obj or mesh_obj.type != 'MESH':
        return

    # Clear old materials
    mesh_obj.data.materials.clear()

    for mat_name in material_names:
        mat = get_or_create_material(mat_name)
        mesh_obj.data.materials.append(mat)
