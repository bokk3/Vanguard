# -*- coding: utf-8 -*-
"""
Socket Attachment System (SOCKET_*).
Inserts Blender Empty objects for weapon hardpoints, thrusters, cameras, and emitter nodes.
Automatically recognized as Static Mesh Sockets by Unreal Engine 5 and Node3D markers by Godot 4.
"""

import bpy
import math
from mathutils import Euler, Vector


def create_sockets(parent_obj, socket_dict, display_size=0.4):
    """
    Creates or updates SOCKET_* Blender Empty objects parented to parent_obj.
    socket_dict is a mapping of socket_name -> (x, y, z) or (x, y, z, rx, ry, rz).
    """
    if not parent_obj:
        return []

    created_sockets = []

    # Clean up existing matching sockets
    existing = [child for child in parent_obj.children if child.name.startswith("SOCKET_")]
    for child in existing:
        bpy.data.objects.remove(child, do_unlink=True)

    for socket_name, coords in socket_dict.items():
        loc = Vector(coords[:3])
        rot = Euler((0, 0, 0), 'XYZ')
        if len(coords) >= 6:
            rot = Euler((math.radians(coords[3]), math.radians(coords[4]), math.radians(coords[5])), 'XYZ')

        empty = bpy.data.objects.new(socket_name, None)
        empty.empty_display_type = 'ARROWS'
        empty.empty_display_size = display_size
        empty.location = loc
        empty.rotation_euler = rot

        # Ensure object is linked to scene collection
        bpy.context.collection.objects.link(empty)
        empty.parent = parent_obj
        created_sockets.append(empty)

    return created_sockets
