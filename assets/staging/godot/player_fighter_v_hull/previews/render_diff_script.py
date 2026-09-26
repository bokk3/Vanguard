
import bpy, os, sys, json, math
from mathutils import Vector, Euler

args = sys.argv[sys.argv.index('--') + 1:]
active_glb = args[0]
staged_glb = args[1]
previews_dir = args[2]
metrics_json = args[3]

os.makedirs(previews_dir, exist_ok=True)

def inspect_and_render(glb_path, label):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    
    # 1. Collect Hierarchy & Node Metrics
    nodes = {}
    for o in bpy.data.objects:
        info = {
            'type': o.type,
            'parent': o.parent.name if o.parent else None,
            'location': [round(v, 4) for v in o.matrix_world.translation],
            'local_loc': [round(v, 4) for v in o.location],
        }
        if o.type == 'MESH':
            info['verts'] = len(o.data.vertices)
            info['faces'] = len(o.data.polygons)
            info['materials'] = [m.name for m in o.material_slots if m]
        nodes[o.name] = info

    # 2. Setup Camera & Shading
    cam_data = bpy.data.cameras.new('ReviewCam')
    cam_obj = bpy.data.objects.new('ReviewCam', cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'MATERIAL'
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = 'BOTH'
    scene.display.shading.show_shadows = True
    scene.render.film_transparent = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 650

    # Hide collision hulls for visual renders
    for o in bpy.data.objects:
        if o.name.startswith('UCX_') or o.name.endswith('-convcol') or o.name.endswith('-colonly'):
            o.hide_render = True

    views = [
        ('top', Vector((0.0, 0.0, 16.0)), Euler((0, 0, 0), 'XYZ'), 15.0),
        ('front', Vector((0.0, 16.0, 0.3)), Euler((math.radians(90), 0, math.radians(180)), 'XYZ'), 13.0),
        ('side', Vector((-16.0, 0.0, 0.3)), Euler((math.radians(90), 0, math.radians(-90)), 'XYZ'), 15.0),
        ('iso', Vector((-9.5, -9.5, 6.5)), None, 15.0),
    ]

    for v_name, loc, rot, scale in views:
        cam_obj.location = loc
        if rot is not None:
            cam_obj.rotation_euler = rot
        else:
            direction = Vector((0.0, 0.0, 0.2)) - loc
            cam_obj.rotation_euler = direction.to_track_quat('-Z', 'Z').to_euler()
        cam_data.type = 'ORTHO'
        cam_data.ortho_scale = scale
        out_file = os.path.join(previews_dir, f'{label}_{v_name}.png')
        scene.render.filepath = out_file
        bpy.ops.render.render(write_still=True)

    # 3. Collision Wireframe Render (only for staged)
    if label == 'staged':
        colors = {
            'UCX_Fuselage': (0.1, 0.8, 1.0, 1.0),      # Neon Cyan
            'UCX_Wing_L': (1.0, 0.75, 0.1, 1.0),       # Amber Gold
            'UCX_Wing_R': (1.0, 0.75, 0.1, 1.0),       # Amber Gold
            'UCX_Ventral_Keel': (0.2, 1.0, 0.3, 1.0),  # Neon Green
        }
        for name, col in colors.items():
            o = bpy.data.objects.get(name)
            if o:
                o.hide_render = False
                mat = bpy.data.materials.new(name=f'M_{name}')
                mat.use_nodes = True
                bsdf = mat.node_tree.nodes.get('Principled BSDF')
                if bsdf:
                    bsdf.inputs['Base Color'].default_value = col
                o.data.materials.clear()
                o.data.materials.append(mat)
                wire = o.modifiers.new(name='Wire', type='WIREFRAME')
                wire.thickness = 0.035
                wire.use_replace = True

        for o in bpy.data.objects:
            if o.name.endswith('-convcol'):
                o.hide_render = True

        cam_obj.location = Vector((-9.5, -9.5, 6.5))
        direction = Vector((0.0, 0.0, 0.2)) - cam_obj.location
        cam_obj.rotation_euler = direction.to_track_quat('-Z', 'Z').to_euler()
        cam_data.type = 'ORTHO'
        cam_data.ortho_scale = 15.0
        out_col = os.path.join(previews_dir, 'staged_collision_overlay.png')
        scene.render.filepath = out_col
        bpy.ops.render.render(write_still=True)

    return nodes

active_nodes = inspect_and_render(active_glb, 'active')
staged_nodes = inspect_and_render(staged_glb, 'staged')

with open(metrics_json, 'w') as f:
    json.dump({'active': active_nodes, 'staged': staged_nodes}, f, indent=2)

print('BLENDER_COMPLETE')
