# -*- coding: utf-8 -*-
"""
Polishing and engine preparation modules.
"""

from .scale_normalizer import normalize_scale
from .hard_surface import apply_hard_surface_polishing, polish_all_meshes
from .materials import setup_asset_materials, get_or_create_material
from .sockets import create_sockets
from .collision import generate_collision_hulls
from .lod import generate_lods

__all__ = [
    "normalize_scale",
    "apply_hard_surface_polishing",
    "polish_all_meshes",
    "setup_asset_materials",
    "get_or_create_material",
    "create_sockets",
    "generate_collision_hulls",
    "generate_lods",
]
