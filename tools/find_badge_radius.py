import math
import numpy as np
from PIL import Image

src_path = r"docs/lore/images/vanguard_squadron_patch.jpg"
img = Image.open(src_path).convert("RGB")
arr = np.array(img, dtype=float)
h, w, _ = arr.shape

# Let's find the circle center and radius accurately
# Along 360 rays from assumed center (512, 512):
# The patch edge is characterized by high blue-to-red ratio or transition from blue embroidery to dark background.
# Blue edge: B > 50 and B > R + 20. Carbon fiber: B ~ R ~ G (gray/black)
# Let's scan along rays from radius 340 to 400 to find the dropoff point.

rays = []
for deg in range(0, 360, 5):
    rad = math.radians(deg)
    cos_a = math.cos(rad)
    sin_a = math.sin(rad)
    
    # scan r from 350 to 395
    # find where blue content drops off
    edge_r = None
    for r in np.linspace(350, 395, 91):
        x = int(512 + r * cos_a)
        y = int(512 + r * sin_a)
        if 0 <= x < w and 0 <= y < h:
            R, G, B = arr[y, x]
            # blue excess
            blue_excess = B - (R + G) / 2.0
            # When blue_excess drops below 5.0 and total brightness drops
            if blue_excess < 8.0 and (r > 365):
                edge_r = r
                break
    if edge_r:
        rays.append((deg, edge_r, 512 + edge_r * cos_a, 512 + edge_r * sin_a))

radii = [r[1] for r in rays]
print(f"Detected {len(rays)} boundary points. Mean radius = {np.mean(radii):.2f}, min = {np.min(radii):.2f}, max = {np.max(radii):.2f}")
