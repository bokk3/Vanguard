# -*- coding: utf-8 -*-
"""
Procedural Terrain & Ground PBR Texture Generator for Project Vanguard.
Generates seamless 1024x1024 PBR texture maps for multi-scale ground rendering:
1. terrain_macro_noise.png - Multi-octave fBm geological noise for regional color modulation
2. terrain_micro_normal.png - Tangent-space normal map for fine rock facets, gravel, and cracks
3. terrain_micro_roughness.png - Micro-roughness map for anisotropic ground glints under sunlight
4. runway_corridor_grid.png - Aerospace corridor / runway navigation markings and distance tick marks
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

def generate_seamless_fbm(width=1024, height=1024, octaves=6, persistence=0.5, lacunarity=2.0, base_freq=4):
    """Generates seamless 2D fractal Brownian motion noise using 4D torus sampling."""
    # Sample on a 4D torus to guarantee perfect seamless tiling
    x = np.linspace(0, 2 * np.pi, width, endpoint=False)
    y = np.linspace(0, 2 * np.pi, height, endpoint=False)
    xv, yv = np.meshgrid(x, y)
    
    total = np.zeros((height, width), dtype=np.float32)
    amplitude = 1.0
    frequency = float(base_freq)
    max_val = 0.0
    
    np.random.seed(42)
    
    for _ in range(octaves):
        # 4D coordinates
        r1 = frequency
        r2 = frequency
        nx = r1 * np.cos(xv)
        ny = r1 * np.sin(xv)
        nz = r2 * np.cos(yv)
        nw = r2 * np.sin(yv)
        
        # Fast pseudorandom phase sum
        phase1 = np.sin(nx * 0.8 + ny * 1.3) * np.cos(nz * 1.1 - nw * 0.7)
        phase2 = np.cos(nx * 1.4 - nw * 1.2) * np.sin(ny * 0.9 + nz * 1.5)
        layer = (phase1 + phase2) * 0.5
        
        total += layer * amplitude
        max_val += amplitude
        amplitude *= persistence
        frequency *= lacunarity
        
    total = (total / max_val + 1.0) * 0.5
    return np.clip(total, 0.0, 1.0)

def height_to_normal_map(height_map, strength=4.0):
    """Computes a tangent-space normal map from a seamless height map using Sobel filters."""
    h, w = height_map.shape
    
    # Periodic boundary padding for seamless normal derivation
    padded = np.pad(height_map, 1, mode='wrap')
    
    # Sobel kernels for horizontal (dx) and vertical (dy) gradients
    # padded shape is (h+2, w+2)
    # central window is [1:-1, 1:-1]
    top_left     = padded[0:-2, 0:-2]
    top          = padded[0:-2, 1:-1]
    top_right    = padded[0:-2, 2:]
    left         = padded[1:-1, 0:-2]
    right        = padded[1:-1, 2:]
    bottom_left  = padded[2:, 0:-2]
    bottom       = padded[2:, 1:-1]
    bottom_right = padded[2:, 2:]
    
    dx = (top_right + 2.0 * right + bottom_right) - (top_left + 2.0 * left + bottom_left)
    dy = (bottom_left + 2.0 * bottom + bottom_right) - (top_left + 2.0 * top + top_right)
    
    # Normal vector components in tangent space: (-dx * strength, -dy * strength, 1.0)
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height_map)
    
    # Normalize
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx /= length
    ny /= length
    nz /= length
    
    # Map [-1, 1] to [0, 255] RGB
    r = ((nx * 0.5 + 0.5) * 255).astype(np.uint8)
    g = ((ny * 0.5 + 0.5) * 255).astype(np.uint8)
    b = ((nz * 0.5 + 0.5) * 255).astype(np.uint8)
    
    return np.stack([r, g, b], axis=-1)

def generate_micro_detail_maps(width=1024, height=1024):
    """Generates high-frequency gravel, pebble, and crack normal + roughness maps."""
    # High base frequency for micro detail (tiles every 5-10m)
    fbm_high = generate_seamless_fbm(width, height, octaves=5, persistence=0.55, lacunarity=2.2, base_freq=18)
    
    # Add sharp micro-cellular cracks / grain
    grain = np.random.RandomState(1337).normal(0.5, 0.15, (height, width))
    grain = np.clip(grain, 0.0, 1.0)
    
    combined_micro_h = fbm_high * 0.75 + grain * 0.25
    
    # Generate normal map
    normal_rgb = height_to_normal_map(combined_micro_h, strength=6.5)
    
    # Roughness: non-uniform micro-facets (rock is mostly rough 0.65-0.95, embedded quartz/silica flakes are 0.35)
    roughness = (0.7 + (1.0 - combined_micro_h) * 0.25 - (grain > 0.85).astype(np.float32) * 0.35)
    roughness = (np.clip(roughness, 0.1, 1.0) * 255).astype(np.uint8)
    
    return normal_rgb, roughness

def generate_runway_corridor_markings(width=1024, height=1024):
    """Generates tactical aerospace launch corridor / runway markings mask."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # White markings RGBA
    white = (255, 255, 255, 255)
    yellow = (255, 204, 0, 255)
    cyan = (0, 230, 255, 240)
    
    # 1. Outer boundary guide lines (X = 120 and X = width - 120)
    line_w = 12
    draw.rectangle([120 - line_w // 2, 0, 120 + line_w // 2, height], fill=yellow)
    draw.rectangle([width - 120 - line_w // 2, 0, width - 120 + line_w // 2, height], fill=yellow)
    
    # 2. Dashed centerline (center at X = 512, length 140, gap 100)
    cx = width // 2
    dash_len = 160
    dash_gap = 96
    step = dash_len + dash_gap
    for y in range(0, height, step):
        draw.rectangle([cx - 10, y, cx + 10, min(height, y + dash_len)], fill=white)
        
    # 3. Lateral distance tick bars every 256 pixels
    for y in [128, 384, 640, 896]:
        # Left ticks
        draw.rectangle([140, y - 6, 260, y + 6], fill=cyan)
        # Right ticks
        draw.rectangle([width - 260, y - 6, width - 140, y + 6], fill=cyan)
        
    # 4. Chevrons / arrows at center points
    for cy in [256, 768]:
        pts = [
            (cx - 70, cy + 40),
            (cx, cy - 30),
            (cx + 70, cy + 40),
            (cx + 50, cy + 55),
            (cx, cy + 5),
            (cx - 50, cy + 55)
        ]
        draw.polygon(pts, fill=white)
        
    return img

def main():
    target_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "godot_project", "textures", "terrain"))
    os.makedirs(target_dir, exist_ok=True)
    print(f"Generating terrain PBR texture suite in: {target_dir}...")
    
    # 1. Macro Geological Noise
    print("[1/4] Generating seamless macro geological strata texture (1024x1024)...")
    macro_noise = generate_seamless_fbm(1024, 1024, octaves=6, persistence=0.52, lacunarity=2.0, base_freq=3)
    macro_img = Image.fromarray((macro_noise * 255).astype(np.uint8), mode='L')
    macro_path = os.path.join(target_dir, "terrain_macro_noise.png")
    macro_img.save(macro_path)
    print(f"  -> Saved: {macro_path}")
    
    # 2. Micro Normal & Roughness
    print("[2/4] Generating high-frequency micro rock normal & roughness maps (1024x1024)...")
    micro_normal, micro_roughness = generate_micro_detail_maps(1024, 1024)
    normal_img = Image.fromarray(micro_normal, mode='RGB')
    normal_path = os.path.join(target_dir, "terrain_micro_normal.png")
    normal_img.save(normal_path)
    print(f"  -> Saved: {normal_path}")
    
    rough_img = Image.fromarray(micro_roughness, mode='L')
    rough_path = os.path.join(target_dir, "terrain_micro_roughness.png")
    rough_img.save(rough_path)
    print(f"  -> Saved: {rough_path}")
    
    # 3. Runway / Launch Corridor Overlay
    print("[3/4] Generating tactical launch corridor markings texture (1024x1024)...")
    runway_img = generate_runway_corridor_markings(1024, 1024)
    runway_path = os.path.join(target_dir, "runway_corridor_markings.png")
    runway_img.save(runway_path)
    print(f"  -> Saved: {runway_path}")
    
    print("[4/4] All terrain textures successfully generated and ready for Godot 4 shaders!")

if __name__ == "__main__":
    main()
