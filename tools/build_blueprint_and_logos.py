import os
import math
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = r"docs/lore/images"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def create_supersampled(size, scale=4):
    w, h = size
    img = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    return img, draw, scale

def finalize(img, target_size):
    return img.resize(target_size, Image.Resampling.LANCZOS)

# -------------------------------------------------------------
# 1. TOP-DOWN FIGHTER BLUEPRINT (1024 x 1024) - Transparent HUD Wireframe
# -------------------------------------------------------------
def build_fighter_blueprint():
    img, draw, s = create_supersampled((1024, 1024), scale=3)
    cx, cy = 512 * s, 480 * s

    # Background subtle coordinate grid
    grid_spacing = 64 * s
    for gx in range(64 * s, 1024 * s, grid_spacing):
        draw.line([(gx, 64 * s), (gx, 960 * s)], fill=(0, 229, 255, 20), width=int(1 * s))
    for gy in range(64 * s, 960 * s, grid_spacing):
        draw.line([(64 * s, gy), (960 * s, gy)], fill=(0, 229, 255, 20), width=int(1 * s))

    # Outer tactical bounding box with corner tick brackets
    b_min, b_max = 64 * s, 960 * s
    draw.rectangle([b_min, b_min, b_max, b_max], outline=(0, 229, 255, 50), width=int(1.5 * s))
    corner_len = 32 * s
    for c_x, c_y in [(b_min, b_min), (b_max, b_min), (b_min, b_max), (b_max, b_max)]:
        dx = corner_len if c_x == b_min else -corner_len
        dy = corner_len if c_y == b_min else -corner_len
        draw.line([(c_x, c_y), (c_x + dx, c_y)], fill=(0, 229, 255, 200), width=int(3 * s))
        draw.line([(c_x, c_y), (c_x, c_y + dy)], fill=(0, 229, 255, 200), width=int(3 * s))

    # Centerline & Wing Span Reference Lines
    draw.line([(cx, 90 * s), (cx, 870 * s)], fill=(0, 229, 255, 80), width=int(1.5 * s)) # Fuselage Centerline
    draw.line([(140 * s, cy + 80 * s), (884 * s, cy + 80 * s)], fill=(0, 229, 255, 60), width=int(1.2 * s)) # 25% Chord Line

    # 1. Sculpted V-Hull Interceptor Wireframe Geometry
    # Real dimensions: Length 10.3m, Span 9.78m
    # Scale factor: ~60 pixels/meter => Length ~620 px, Span ~586 px
    L = 310 * s
    W = 293 * s

    # Main Fuselage & Delta Wings Outer Contour
    hull_pts = [
        (cx, cy - L),                        # 0. Nose Tip
        (cx + 22 * s, cy - L + 75 * s),       # 1. Forward Radome
        (cx + 38 * s, cy - L + 160 * s),      # 2. Cockpit Base
        (cx + 85 * s, cy - L + 220 * s),      # 3. LERX / Strakes
        (cx + W, cy + 120 * s),              # 4. Right Wingtip (Missile rail)
        (cx + W - 15 * s, cy + 155 * s),     # 5. Right Trailing Edge Outer
        (cx + 175 * s, cy + 145 * s),        # 6. Elevon Inboard
        (cx + 115 * s, cy + 235 * s),        # 7. Engine Nacelle R Outer
        (cx + 45 * s, cy + 240 * s),         # 8. Engine R Nozzle
        (cx + 20 * s, cy + 215 * s),         # 9. Ventral Keel Notch
        (cx - 20 * s, cy + 215 * s),         # 10. Ventral Keel Notch L
        (cx - 45 * s, cy + 240 * s),         # 11. Engine L Nozzle
        (cx - 115 * s, cy + 235 * s),        # 12. Engine Nacelle L Outer
        (cx - 175 * s, cy + 145 * s),        # 13. Elevon Inboard L
        (cx - W + 15 * s, cy + 155 * s),     # 14. Left Trailing Edge Outer
        (cx - W, cy + 120 * s),              # 15. Left Wingtip
        (cx - 85 * s, cy - L + 220 * s),     # 16. LERX / Strakes L
        (cx - 38 * s, cy - L + 160 * s),     # 17. Cockpit Base L
        (cx - 22 * s, cy - L + 75 * s),      # 18. Forward Radome L
    ]

    # Fill translucent blueprint interior
    draw.polygon(hull_pts, fill=(13, 71, 161, 45), outline=(0, 229, 255, 230), width=int(2.5 * s))

    # Cockpit Diamond Facet Canopy
    canopy_pts = [
        (cx, cy - L + 110 * s),
        (cx + 18 * s, cy - L + 185 * s),
        (cx, cy - L + 235 * s),
        (cx - 18 * s, cy - L + 185 * s),
    ]
    draw.polygon(canopy_pts, fill=(0, 229, 255, 80), outline=(255, 255, 255, 240), width=int(2 * s))
    draw.line([(cx, cy - L + 110 * s), (cx, cy - L + 235 * s)], fill=(255, 255, 255, 180), width=int(1.5 * s))

    # Twin Engine Exhaust Nozzles
    draw.ellipse([cx + 52 * s, cy + 210 * s, cx + 102 * s, cy + 250 * s], outline=(0, 229, 255, 240), fill=(0, 180, 216, 90), width=int(2 * s))
    draw.ellipse([cx - 102 * s, cy + 210 * s, cx - 52 * s, cy + 250 * s], outline=(0, 229, 255, 240), fill=(0, 180, 216, 90), width=int(2 * s))

    # 4x Wing Pylons & Mounted Vanguard Strike Missiles
    # Hardpoint stations according to repo docs:
    # Station 01: x=-3.60m, Station 02: x=-2.60m, Station 03: x=+2.60m, Station 04: x=+3.60m
    pylon_offsets = [
        (cx - 215 * s, cy + 50 * s, "STA 01 [VPSM-01]"),
        (cx - 145 * s, cy + 70 * s, "STA 02 [VPSM-01]"),
        (cx + 145 * s, cy + 70 * s, "STA 03 [VPSM-01]"),
        (cx + 215 * s, cy + 50 * s, "STA 04 [VPSM-01]"),
    ]

    for px, py, label in pylon_offsets:
        # Pylon rail
        draw.rectangle([px - 4 * s, py - 40 * s, px + 4 * s, py + 35 * s], fill=(236, 239, 241, 200), outline=(0, 229, 255, 240), width=int(1.5 * s))
        # Missile body
        draw.rectangle([px - 7 * s, py - 65 * s, px + 7 * s, py + 55 * s], fill=(207, 216, 220, 220), outline=(255, 179, 0, 230), width=int(1.8 * s))
        # Missile nose cone (tangent ogive)
        draw.polygon([(px - 7 * s, py - 65 * s), (px + 7 * s, py - 65 * s), (px, py - 85 * s)], fill=(255, 23, 68, 220))
        # Cruciform fins
        draw.line([(px - 18 * s, py + 45 * s), (px + 18 * s, py + 45 * s)], fill=(255, 179, 0, 255), width=int(2.5 * s))

        # Hardpoint HUD callout circle
        draw.ellipse([px - 10 * s, py - 10 * s, px + 10 * s, py + 10 * s], outline=(255, 179, 0, 255), width=int(2 * s))

    # Ventral Diamond FLIR Targeting Pod
    draw.polygon([(cx, cy - L + 280 * s), (cx + 12 * s, cy - L + 295 * s), (cx, cy - L + 310 * s), (cx - 12 * s, cy - L + 295 * s)], fill=(0, 229, 255, 200), outline=(255, 255, 255, 255), width=int(1.5 * s))

    # Nose 20mm Rotary Autocannon Muzzle
    draw.rectangle([cx - 5 * s, cy - L + 20 * s, cx + 5 * s, cy - L + 60 * s], fill=(38, 50, 56, 230), outline=(255, 23, 68, 230), width=int(1.5 * s))

    # Technical Annotation Dimension Lines
    # Length line (Left side)
    dim_x = 100 * s
    draw.line([(dim_x, cy - L), (dim_x, cy + 240 * s)], fill=(255, 179, 0, 220), width=int(2 * s))
    draw.line([(dim_x - 15 * s, cy - L), (dim_x + 15 * s, cy - L)], fill=(255, 179, 0, 220), width=int(2 * s))
    draw.line([(dim_x - 15 * s, cy + 240 * s), (dim_x + 15 * s, cy + 240 * s)], fill=(255, 179, 0, 220), width=int(2 * s))

    # Wingspan line (Bottom)
    dim_y = 860 * s
    draw.line([(cx - W, dim_y), (cx + W, dim_y)], fill=(255, 179, 0, 220), width=int(2 * s))
    draw.line([(cx - W, dim_y - 15 * s), (cx - W, dim_y + 15 * s)], fill=(255, 179, 0, 220), width=int(2 * s))
    draw.line([(cx + W, dim_y - 15 * s), (cx + W, dim_y + 15 * s)], fill=(255, 179, 0, 220), width=int(2 * s))

    out = finalize(img, (1024, 1024))
    out.save(os.path.join(OUTPUT_DIR, "fighter_blueprint_topdown.png"))
    print("Saved docs/lore/images/fighter_blueprint_topdown.png")

# -------------------------------------------------------------
# 2. TITLE WORDMARK LOGO (800 x 220) - Transparent Vector Style
# -------------------------------------------------------------
def build_title_logo():
    img, draw, s = create_supersampled((800, 220), scale=4)
    cx, cy = 400 * s, 100 * s

    # Stylized glowing chevron backdrop
    ch_pts = [
        (cx - 320 * s, cy - 60 * s),
        (cx, cy - 25 * s),
        (cx + 320 * s, cy - 60 * s),
        (cx + 280 * s, cy - 45 * s),
        (cx, cy - 10 * s),
        (cx - 280 * s, cy - 45 * s)
    ]
    draw.polygon(ch_pts, fill=(0, 229, 255, 180))

    # Main "VANGUARD" polygon lettering lines
    # Outer bounding frame
    draw.line([(cx - 360 * s, cy + 50 * s), (cx + 360 * s, cy + 50 * s)], fill=(0, 229, 255, 160), width=int(2.5 * s))
    draw.line([(cx - 360 * s, cy + 58 * s), (cx + 360 * s, cy + 58 * s)], fill=(0, 229, 255, 60), width=int(1.5 * s))

    # Flanking tactical triangles
    draw.polygon([(cx - 375 * s, cy + 50 * s), (cx - 360 * s, cy + 40 * s), (cx - 360 * s, cy + 60 * s)], fill=(255, 179, 0, 240))
    draw.polygon([(cx + 375 * s, cy + 50 * s), (cx + 360 * s, cy + 40 * s), (cx + 360 * s, cy + 60 * s)], fill=(255, 179, 0, 240))

    out = finalize(img, (800, 220))
    out.save(os.path.join(OUTPUT_DIR, "vanguard_title_logo.png"))
    print("Saved docs/lore/images/vanguard_title_logo.png")

# -------------------------------------------------------------
# 3. HELION EXTRACTION COMBAT ENEMY FACTION CREST (512 x 512)
# -------------------------------------------------------------
def build_combine_crest():
    img, draw, s = create_supersampled((512, 512), scale=4)
    cx, cy = 256 * s, 256 * s

    # Aggressive hexagonal outer frame
    hex_r = 210 * s
    hex_pts = []
    for i in range(6):
        angle = math.radians(60 * i - 30)
        hex_pts.append((cx + hex_r * math.cos(angle), cy + hex_r * math.sin(angle)))
    draw.polygon(hex_pts, outline=(213, 0, 0, 240), fill=(20, 20, 22, 180), width=int(6 * s))

    # Inner segmented hazard hex
    in_r = 165 * s
    in_pts = []
    for i in range(6):
        angle = math.radians(60 * i - 30)
        in_pts.append((cx + in_r * math.cos(angle), cy + in_r * math.sin(angle)))
    draw.polygon(in_pts, outline=(184, 115, 51, 230), width=int(3 * s))

    # Central aggressive claw / extraction drill glyph
    # 3 interlocked predatory red chevrons pointing downward
    tri_pts = [
        (cx, cy + 110 * s),
        (cx + 85 * s, cy - 50 * s),
        (cx + 45 * s, cy - 85 * s),
        (cx, cy - 25 * s),
        (cx - 45 * s, cy - 85 * s),
        (cx - 85 * s, cy - 50 * s),
    ]
    draw.polygon(tri_pts, fill=(213, 0, 0, 255), outline=(255, 82, 82, 255), width=int(3 * s))

    # Core black diamond
    core = [
        (cx, cy + 30 * s),
        (cx + 35 * s, cy - 20 * s),
        (cx, cy - 70 * s),
        (cx - 35 * s, cy - 20 * s),
    ]
    draw.polygon(core, fill=(10, 10, 12, 255), outline=(184, 115, 51, 255), width=int(2.5 * s))

    out = finalize(img, (512, 512))
    out.save(os.path.join(OUTPUT_DIR, "faction_combine_crest.png"))
    print("Saved docs/lore/images/faction_combine_crest.png")

# -------------------------------------------------------------
# 4. SOL ORBITAL DIRECTORATE CREST (512 x 512)
# -------------------------------------------------------------
def build_sol_crest():
    img, draw, s = create_supersampled((512, 512), scale=4)
    cx, cy = 256 * s, 256 * s

    # Circular planetary ring
    r_outer = 210 * s
    draw.ellipse([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], outline=(13, 71, 161, 240), fill=(10, 25, 47, 180), width=int(6 * s))
    
    # Inner gold laurel / orbital meridian
    r_mid = 170 * s
    draw.ellipse([cx - r_mid, cy - r_mid, cx + r_mid, cy + r_mid], outline=(255, 179, 0, 230), width=int(3 * s))

    # Crossed orbital ascension tracks (forming stylized diamond & globe)
    draw.arc([cx - r_mid, cy - 80 * s, cx + r_mid, cy + 80 * s], start=0, end=360, fill=(0, 229, 255, 230), width=int(3 * s))
    
    # Central ascending arrowhead
    arrow = [
        (cx, cy - 120 * s),
        (cx + 60 * s, cy + 35 * s),
        (cx + 25 * s, cy + 20 * s),
        (cx, cy + 70 * s),
        (cx - 25 * s, cy + 20 * s),
        (cx - 60 * s, cy + 35 * s),
    ]
    draw.polygon(arrow, fill=(236, 239, 241, 255), outline=(0, 229, 255, 255), width=int(2.5 * s))

    out = finalize(img, (512, 512))
    out.save(os.path.join(OUTPUT_DIR, "faction_sol_crest.png"))
    print("Saved docs/lore/images/faction_sol_crest.png")

print("Building blueprint and faction crests...")
build_fighter_blueprint()
build_title_logo()
build_combine_crest()
build_sol_crest()
print("All transparent blueprint and faction assets generated successfully.")
