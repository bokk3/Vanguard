import numpy as np
from PIL import Image, ImageDraw, ImageFilter

src_path = r"docs/lore/images/vanguard_squadron_patch.jpg"
img = Image.open(src_path).convert("RGBA")
w, h = img.size

# Supersampled anti-aliased mask
scale = 4
mask_hi = Image.new("L", (w * scale, h * scale), 0)
draw = ImageDraw.Draw(mask_hi)

cx = w * scale / 2.0
cy = h * scale / 2.0
# Radius at normal scale is ~378.5 to cleanly clip inside the stitched thread border without carbon halo
r = 378.0 * scale

draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)

# Downsample mask with high quality lanczos/box filter for perfect anti-aliasing
mask = mask_hi.resize((w, h), Image.Resampling.LANCZOS)

# Apply mask
out = img.copy()
out.putalpha(mask)

# Save full-size 1024x1024 transparent PNG
out.save(r"docs/lore/images/vanguard_squadron_patch.png", "PNG")
print("Saved docs/lore/images/vanguard_squadron_patch.png")

# Tight crop to content (around radius 378 => 756x756 + small padding = 768x768)
crop_box = (int(512 - 380), int(512 - 380), int(512 + 380), int(512 + 380))
cropped = out.crop(crop_box)
cropped.save(r"docs/lore/images/vanguard_squadron_patch_cropped.png", "PNG")
print(f"Saved docs/lore/images/vanguard_squadron_patch_cropped.png ({cropped.size})")
