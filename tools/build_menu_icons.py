import os
import math
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = r"docs/lore/images"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def create_supersampled(size, scale=4):
    """Creates a high-res RGBA image for supersampled anti-aliased drawing."""
    w, h = size
    img = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    return img, draw, scale

def finalize(img, target_size):
    """Downsamples high-res RGBA image with Lanczos filter for smooth edges."""
    return img.resize(target_size, Image.Resampling.LANCZOS)

# -------------------------------------------------------------
# 1. MENU BUTTON ICONS (128x128 & 64x64)
# -------------------------------------------------------------

def build_icon_deploy():
    """Deploy Sortie: Ascending Interceptor inside diamond tactical brackets."""
    img, draw, s = create_supersampled((128, 128))
    cx, cy = 64 * s, 64 * s

    # Outer diamond bracket
    r = 52 * s
    pts = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
    draw.polygon(pts, outline=(0, 229, 255, 140), width=int(2.5 * s))

    # Corner ticks
    t = 12 * s
    draw.line([(cx, cy - r), (cx, cy - r + t)], fill=(0, 229, 255, 255), width=int(3.5 * s))
    draw.line([(cx, cy + r), (cx, cy + r - t)], fill=(0, 229, 255, 255), width=int(3.5 * s))
    draw.line([(cx - r, cy), (cx - r + t, cy)], fill=(0, 229, 255, 255), width=int(3.5 * s))
    draw.line([(cx + r, cy), (cx + r - t, cy)], fill=(0, 229, 255, 255), width=int(3.5 * s))

    # Inner climbing interceptor silhouette
    # Nose (0, -32), Wings (28, 18), Tail (0, 10), Wingtips, etc.
    fighter = [
        (cx, cy - 30 * s),
        (cx + 6 * s, cy - 12 * s),
        (cx + 28 * s, cy + 14 * s),
        (cx + 26 * s, cy + 20 * s),
        (cx + 10 * s, cy + 16 * s),
        (cx + 8 * s, cy + 24 * s),
        (cx, cy + 20 * s),
        (cx - 8 * s, cy + 24 * s),
        (cx - 10 * s, cy + 16 * s),
        (cx - 26 * s, cy + 20 * s),
        (cx - 28 * s, cy + 14 * s),
        (cx - 6 * s, cy - 12 * s),
    ]
    draw.polygon(fighter, fill=(236, 239, 241, 240), outline=(0, 229, 255, 255), width=int(2 * s))

    # Afterburner jet plume
    draw.line([(cx - 4 * s, cy + 24 * s), (cx - 4 * s, cy + 34 * s)], fill=(0, 229, 255, 255), width=int(2.5 * s))
    draw.line([(cx + 4 * s, cy + 24 * s), (cx + 4 * s, cy + 34 * s)], fill=(0, 229, 255, 255), width=int(2.5 * s))

    out = finalize(img, (128, 128))
    out.save(os.path.join(OUTPUT_DIR, "menu_icon_deploy.png"))

def build_icon_config():
    """Avionics Config: Avionics crosshair, radar ring and tuning sliders."""
    img, draw, s = create_supersampled((128, 128))
    cx, cy = 64 * s, 64 * s

    # Circular radar frame
    r = 48 * s
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(0, 229, 255, 120), width=int(2.5 * s))
    
    # Inner ring
    r2 = 32 * s
    draw.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], outline=(0, 229, 255, 80), width=int(1.5 * s))

    # Crosshair axes
    draw.line([(cx - 52 * s, cy), (cx + 52 * s, cy)], fill=(0, 229, 255, 180), width=int(2 * s))
    draw.line([(cx, cy - 52 * s), (cx, cy + 52 * s)], fill=(0, 229, 255, 180), width=int(2 * s))

    # Diagnostic sliders / equalization bars
    bars = [
        (-24 * s, 10 * s),
        (-12 * s, 20 * s),
        (0 * s, 28 * s),
        (12 * s, 16 * s),
        (24 * s, 8 * s)
    ]
    for bx, bh in bars:
        draw.line([(cx + bx, cy + 6 * s), (cx + bx, cy + 6 * s - bh)], fill=(255, 179, 0, 240), width=int(3 * s))
        draw.rectangle([cx + bx - 3 * s, cy + 6 * s - bh - 3 * s, cx + bx + 3 * s, cy + 6 * s - bh + 1 * s], fill=(255, 255, 255, 255))

    out = finalize(img, (128, 128))
    out.save(os.path.join(OUTPUT_DIR, "menu_icon_config.png"))

def build_icon_specs():
    """Fighter Specs: Isometric CAD wireframe blueprint glyph."""
    img, draw, s = create_supersampled((128, 128))
    cx, cy = 64 * s, 64 * s

    # Isometric blueprint cube / airframe enclosure
    h = 24 * s
    w = 38 * s
    # Top face
    p_top = [(cx, cy - 32 * s), (cx + w, cy - 14 * s), (cx, cy + 4 * s), (cx - w, cy - 14 * s)]
    draw.polygon(p_top, outline=(0, 229, 255, 230), fill=(13, 71, 161, 80), width=int(2.5 * s))

    # Left face
    p_left = [(cx - w, cy - 14 * s), (cx, cy + 4 * s), (cx, cy + 4 * s + h), (cx - w, cy - 14 * s + h)]
    draw.polygon(p_left, outline=(0, 229, 255, 180), fill=(8, 32, 70, 100), width=int(2 * s))

    # Right face
    p_right = [(cx, cy + 4 * s), (cx + w, cy - 14 * s), (cx + w, cy - 14 * s + h), (cx, cy + 4 * s + h)]
    draw.polygon(p_right, outline=(0, 229, 255, 180), fill=(10, 45, 90, 100), width=int(2 * s))

    # Technical grid lines across top face
    draw.line([(cx - w / 2, cy - 23 * s), (cx + w / 2, cy - 5 * s)], fill=(0, 229, 255, 100), width=int(1.5 * s))
    draw.line([(cx + w / 2, cy - 23 * s), (cx - w / 2, cy - 5 * s)], fill=(0, 229, 255, 100), width=int(1.5 * s))

    # Target reticle center
    draw.ellipse([cx - 4 * s, cy - 14 * s - 4 * s, cx + 4 * s, cy - 14 * s + 4 * s], fill=(255, 179, 0, 255))

    out = finalize(img, (128, 128))
    out.save(os.path.join(OUTPUT_DIR, "menu_icon_specs.png"))

def build_icon_quit():
    """Abort / Quit: Tactical ejection / exit chevron with amber hazard borders."""
    img, draw, s = create_supersampled((128, 128))
    cx, cy = 64 * s, 64 * s

    # Circular hazard ring with notch
    r = 46 * s
    draw.arc([cx - r, cy - r, cx + r, cy + r], start=-60, end=240, fill=(255, 23, 68, 220), width=int(3.5 * s))

    # Power / Ejection vertical tab
    draw.line([(cx, cy - 48 * s), (cx, cy - 16 * s)], fill=(255, 23, 68, 255), width=int(4 * s))

    # Inner emergency triangle
    tr = 22 * s
    tri = [(cx, cy - 6 * s), (cx + tr, cy + 24 * s), (cx - tr, cy + 24 * s)]
    draw.polygon(tri, outline=(255, 179, 0, 240), fill=(255, 23, 68, 80), width=int(2.5 * s))
    
    # Exclamation mark
    draw.line([(cx, cy + 4 * s), (cx, cy + 14 * s)], fill=(255, 255, 255, 255), width=int(2.5 * s))
    draw.point([(cx, cy + 18 * s)], fill=(255, 255, 255, 255))

    out = finalize(img, (128, 128))
    out.save(os.path.join(OUTPUT_DIR, "menu_icon_quit.png"))

print("Building menu button icons...")
build_icon_deploy()
build_icon_config()
build_icon_specs()
build_icon_quit()
print("Menu button icons complete.")
