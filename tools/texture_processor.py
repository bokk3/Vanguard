# -*- coding: utf-8 -*-
"""
PBR Texture Processing & Channel Packer for Unreal Engine 5.
Uses Blender's headless Python environment to generate Normal maps from heightmaps
and pack Ambient Occlusion, Roughness, and Metallic (ORM) channels without external dependencies.
"""

import os
import sys
import argparse
import subprocess
import shutil

def find_blender():
    candidates = [
        shutil.which("blender"),
        os.path.expandvars(r"%USERPROFILE%\tools\blender\blender.exe"),
        r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe"
    ]
    for c in candidates:
        if c and os.path.exists(c):
            return c
    return None

BLENDER_TEXTURE_SCRIPT = '''# -*- coding: utf-8 -*-
import bpy
import sys
import os

mode = "{mode}"
out_path = r"{out_path}"
height_path = r"{height_path}"
ao_path = r"{ao_path}"
rough_path = r"{rough_path}"
metal_path = r"{metal_path}"
strength = {strength}

# Reset scene and enable compositing nodes
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.use_nodes = True
tree = bpy.context.scene.node_tree
tree.nodes.clear()

if mode == "normal":
    print(f"Generating Normal Map from: {{height_path}}")
    # Load height image
    img = bpy.data.images.load(height_path)
    
    img_node = tree.nodes.new(type='CompositorNodeImage')
    img_node.image = img
    
    # Filter / Normal node or Bump node
    normal_node = tree.nodes.new(type='CompositorNodeNormal')
    
    # Alternatively, use custom pixel shader / Sobel calculation
    comp_node = tree.nodes.new(type='CompositorNodeComposite')
    
    # Fast approach: Load image, compute gradients in numpy, save normal map
    import numpy as np
    w, h = img.size
    pixels = np.array(img.pixels[:], dtype=np.float32).reshape((h, w, 4))
    gray = 0.299 * pixels[:, :, 0] + 0.587 * pixels[:, :, 1] + 0.114 * pixels[:, :, 2]
    
    # Sobel gradients
    sobel_x = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=np.float32)
    sobel_y = np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], dtype=np.float32)
    
    # Pad borders
    padded = np.pad(gray, 1, mode='edge')
    
    # Pure numpy Sobel gradient (zero external dependencies)
    gx = ((padded[:-2, 2:] + 2 * padded[1:-1, 2:] + padded[2:, 2:]) - 
          (padded[:-2, :-2] + 2 * padded[1:-1, :-2] + padded[2:, :-2])) * strength
    gy = ((padded[2:, :-2] + 2 * padded[2:, 1:-1] + padded[2:, 2:]) - 
          (padded[:-2, :-2] + 2 * padded[:-2, 1:-1] + padded[:-2, 2:])) * strength
    gz = np.ones_like(gx)
    
    # Normalize vectors
    norm = np.sqrt(gx**2 + gy**2 + gz**2)
    norm[norm == 0] = 1.0
    nx = (gx / norm) * 0.5 + 0.5
    ny = (-gy / norm) * 0.5 + 0.5  # DirectX normal (green inverted for Unreal Engine)
    nz = (gz / norm) * 0.5 + 0.5
    
    # Pack normal image
    normal_pixels = np.stack([nx, ny, nz, np.ones_like(nx)], axis=-1).flatten()
    
    norm_img = bpy.data.images.new("NormalMap", width=w, height=h)
    norm_img.colorspace_settings.name = 'Non-Color'
    norm_img.pixels = normal_pixels.tolist()
    norm_img.filepath_raw = out_path
    norm_img.file_format = 'PNG'
    norm_img.save()
    print(f"[SUCCESS] Normal Map saved: {{out_path}}")

elif mode == "orm":
    print("Packing ORM (Occlusion, Roughness, Metallic) channels for UE5...")
    import numpy as np
    
    # Helper to load channel or create default constant
    def load_channel(path, default_val, target_shape=None):
        if path and os.path.exists(path):
            img = bpy.data.images.load(path)
            w, h = img.size
            px = np.array(img.pixels[:], dtype=np.float32).reshape((h, w, 4))
            return px[:, :, 0], (h, w)
        return None, None
    
    ao, shape_ao = load_channel(ao_path, 1.0)
    rough, shape_r = load_channel(rough_path, 0.5)
    metal, shape_m = load_channel(metal_path, 0.0)
    
    target_shape = shape_ao or shape_r or shape_m or (1024, 1024)
    h, w = target_shape
    
    ao_chan = ao if ao is not None else np.full((h, w), 1.0, dtype=np.float32)
    rough_chan = rough if rough is not None else np.full((h, w), 0.5, dtype=np.float32)
    metal_chan = metal if metal is not None else np.full((h, w), 0.0, dtype=np.float32)
    alpha_chan = np.full((h, w), 1.0, dtype=np.float32)
    
    # Pack R=AO, G=Roughness, B=Metallic, A=1.0
    orm_data = np.stack([ao_chan, rough_chan, metal_chan, alpha_chan], axis=-1).flatten()
    
    orm_img = bpy.data.images.new("ORMMap", width=w, height=h)
    orm_img.colorspace_settings.name = 'Non-Color'
    orm_img.pixels = orm_data.tolist()
    orm_img.filepath_raw = out_path
    orm_img.file_format = 'PNG'
    orm_img.save()
    print(f"[SUCCESS] Packed ORM map saved: {{out_path}}")
'''

def generate_normal_map(height_map_path, output_path, strength=2.0):
    blender = find_blender()
    if not blender:
        print("[ERROR] Blender not found for texture processing.")
        return False
        
    script_content = BLENDER_TEXTURE_SCRIPT.format(
        mode="normal",
        out_path=os.path.abspath(output_path).replace("\\", "/"),
        height_path=os.path.abspath(height_map_path).replace("\\", "/"),
        ao_path="",
        rough_path="",
        metal_path="",
        strength=float(strength)
    )
    
    temp_py = os.path.join(os.path.dirname(__file__), "_temp_tex_job.py")
    with open(temp_py, "w", encoding="utf-8") as f:
        f.write(script_content)
        
    try:
        res = subprocess.run([blender, "-b", "-P", temp_py], capture_output=True, text=True, check=True)
        print(res.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Texture processor error:\n{e.stderr or e.stdout}")
        return False
    finally:
        if os.path.exists(temp_py):
            os.remove(temp_py)


def pack_orm(output_path, ao_path="", roughness_path="", metallic_path=""):
    blender = find_blender()
    if not blender:
        print("[ERROR] Blender not found for texture processing.")
        return False
        
    script_content = BLENDER_TEXTURE_SCRIPT.format(
        mode="orm",
        out_path=os.path.abspath(output_path).replace("\\", "/"),
        height_path="",
        ao_path=os.path.abspath(ao_path).replace("\\", "/") if ao_path else "",
        rough_path=os.path.abspath(roughness_path).replace("\\", "/") if roughness_path else "",
        metal_path=os.path.abspath(metallic_path).replace("\\", "/") if metallic_path else "",
        strength=1.0
    )
    
    temp_py = os.path.join(os.path.dirname(__file__), "_temp_tex_job.py")
    with open(temp_py, "w", encoding="utf-8") as f:
        f.write(script_content)
        
    try:
        res = subprocess.run([blender, "-b", "-P", temp_py], capture_output=True, text=True, check=True)
        print(res.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] ORM pack error:\n{e.stderr or e.stdout}")
        return False
    finally:
        if os.path.exists(temp_py):
            os.remove(temp_py)


def main():
    parser = argparse.ArgumentParser(description="PBR Texture Processing & ORM Packer for UE5")
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    # Normal map subcommand
    n_parser = subparsers.add_parser("normal", help="Generate Normal Map from Heightmap")
    n_parser.add_argument("--height", "-i", required=True, help="Input grayscale heightmap image")
    n_parser.add_argument("--out", "-o", required=True, help="Output Normal map path (.png)")
    n_parser.add_argument("--strength", "-s", type=float, default=2.0, help="Normal depth strength")
    
    # ORM pack subcommand
    orm_parser = subparsers.add_parser("orm", help="Pack AO, Roughness, and Metallic into ORM map")
    orm_parser.add_argument("--out", "-o", required=True, help="Output packed ORM map path (.png)")
    orm_parser.add_argument("--ao", help="Input Ambient Occlusion image (optional)")
    orm_parser.add_argument("--roughness", "-r", help="Input Roughness image (optional)")
    orm_parser.add_argument("--metallic", "-m", help="Input Metallic image (optional)")
    
    args = parser.parse_args()
    if args.command == "normal":
        generate_normal_map(args.height, args.out, args.strength)
    elif args.command == "orm":
        pack_orm(args.out, args.ao or "", args.roughness or "", args.metallic or "")
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
