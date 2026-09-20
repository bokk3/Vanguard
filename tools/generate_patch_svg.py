import base64

# 1. Create vanguard_squadron_patch.svg embedding the transparent PNG inside responsive SVG container
with open(r"docs/lore/images/vanguard_squadron_patch_cropped.png", "rb") as f:
    b64_png = base64.b64encode(f.read()).decode("utf-8")

svg_content = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 760 760" width="100%" height="100%">
  <defs>
    <clipPath id="circular-badge-clip">
      <circle cx="380" cy="380" r="378" />
    </clipPath>
    <filter id="badge-glow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="8" stdDeviation="16" flood-color="#00E5FF" flood-opacity="0.35" />
    </filter>
  </defs>
  <g filter="url(#badge-glow)">
    <image href="data:image/png;base64,{b64_png}" width="760" height="760" clip-path="url(#circular-badge-clip)" />
  </g>
</svg>
'''

with open(r"docs/lore/images/vanguard_squadron_patch.svg", "w", encoding="utf-8") as f:
    f.write(svg_content)

print("Saved docs/lore/images/vanguard_squadron_patch.svg")
