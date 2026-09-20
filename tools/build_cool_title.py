import os
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUTPUT_DIR = r"docs/lore/images"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# 2400 x 640 at 2x supersampling = 4800 x 1280
W, H = 2400, 640
scale = 2
img = Image.new("RGBA", (W * scale, H * scale), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

s = scale
cx = (W * scale) / 2.0
cy = (H * scale) / 2.0 + 15 * s

def draw_chiseled_poly(pts, fill_col, outline_col, shadow_col=None, width=3):
    if shadow_col:
        s_pts = [(x + 4 * s, y + 6 * s) for x, y in pts]
        draw.polygon(s_pts, fill=shadow_col)
    draw.polygon(pts, fill=fill_col, outline=outline_col, width=int(width * s))

H_L = 155 * s
SW = 32 * s

def get_v_poly(x, y, w):
    return [
        (x, y),
        (x + SW, y),
        (x + w/2, y + H_L - 35*s),
        (x + w - SW, y),
        (x + w, y),
        (x + w/2 + 8*s, y + H_L),
        (x + w/2 - 8*s, y + H_L),
    ]

def get_a_poly(x, y, w):
    outer = [
        (x, y + H_L),
        (x + SW, y + H_L),
        (x + w/2 - 4*s, y + 26*s),
        (x + w/2 + 4*s, y + 26*s),
        (x + w - SW, y + H_L),
        (x + w, y + H_L),
        (x + w/2 + 18*s, y),
        (x + w/2 - 18*s, y),
    ]
    inner = [
        (x + w/2, y + 42*s),
        (x + w - SW - 16*s, y + H_L - 38*s),
        (x + SW + 16*s, y + H_L - 38*s),
    ]
    return outer, inner

def get_n_poly(x, y, w):
    return [
        (x, y + 20*s),
        (x + 20*s, y),
        (x + SW, y),
        (x + w - SW, y + H_L - 45*s),
        (x + w - SW, y),
        (x + w, y),
        (x + w, y + H_L - 20*s),
        (x + w - 20*s, y + H_L),
        (x + w - SW, y + H_L),
        (x + SW, y + 45*s),
        (x + SW, y + H_L),
        (x, y + H_L),
    ]

def get_g_poly(x, y, w):
    outer = [
        (x + 35*s, y),
        (x + w, y),
        (x + w, y + SW),
        (x + 35*s + SW*0.6, y + SW),
        (x + SW, y + 35*s + SW*0.6),
        (x + SW, y + H_L - 35*s - SW*0.6),
        (x + 35*s + SW*0.6, y + H_L - SW),
        (x + w - SW, y + H_L - SW),
        (x + w - SW, y + H_L/2),
        (x + w/2 + 5*s, y + H_L/2),
        (x + w/2 + 5*s, y + H_L/2 - SW*0.8),
        (x + w, y + H_L/2 - SW*0.8),
        (x + w, y + H_L - 30*s),
        (x + w - 30*s, y + H_L),
        (x + 35*s, y + H_L),
        (x, y + H_L - 35*s),
        (x, y + 35*s),
    ]
    return outer

def get_u_poly(x, y, w):
    outer = [
        (x, y),
        (x + SW, y),
        (x + SW, y + H_L - 35*s - SW*0.6),
        (x + 35*s + SW*0.6, y + H_L - SW),
        (x + w - 35*s - SW*0.6, y + H_L - SW),
        (x + w - SW, y + H_L - 35*s - SW*0.6),
        (x + w - SW, y),
        (x + w, y),
        (x + w, y + H_L - 35*s),
        (x + w - 35*s, y + H_L),
        (x + 35*s, y + H_L),
        (x, y + H_L - 35*s),
    ]
    return outer

def get_r_poly(x, y, w):
    outer = [
        (x, y),
        (x + w - 30*s, y),
        (x + w, y + 30*s),
        (x + w, y + 70*s),
        (x + w - 30*s, y + 85*s),
        (x + w, y + H_L),
        (x + w - SW*1.3, y + H_L),
        (x + w/2 - 5*s, y + 85*s),
        (x + SW, y + 85*s),
        (x + SW, y + H_L),
        (x, y + H_L),
    ]
    inner = [
        (x + SW, y + SW),
        (x + w - 35*s, y + SW),
        (x + w - SW, y + 45*s),
        (x + w - 35*s, y + 65*s),
        (x + SW, y + 65*s),
    ]
    return outer, inner

def get_d_poly(x, y, w):
    outer = [
        (x, y),
        (x + w - 40*s, y),
        (x + w, y + 40*s),
        (x + w, y + H_L - 40*s),
        (x + w - 40*s, y + H_L),
        (x, y + H_L),
    ]
    inner = [
        (x + SW, y + SW),
        (x + w - 45*s, y + SW),
        (x + w - SW, y + 45*s),
        (x + w - SW, y + H_L - 45*s),
        (x + w - 45*s, y + H_L - SW),
        (x + SW, y + H_L - SW),
    ]
    return outer, inner

letter_widths = [
    115 * s, # V
    115 * s, # A
    108 * s, # N
    112 * s, # G
    108 * s, # U
    115 * s, # A
    110 * s, # R
    110 * s  # D
]
spacing = 22 * s
total_w = sum(letter_widths) + (len(letter_widths) - 1) * spacing
start_x = cx - total_w / 2.0
base_y = cy - H_L / 2.0 + 8 * s

glow_img = Image.new("RGBA", (W * scale, H * scale), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow_img)

for streak_y in range(int(base_y + 10*s), int(base_y + H_L), int(16*s)):
    glow_draw.line([(cx - total_w/2 - 140*s, streak_y), (cx + total_w/2 + 140*s, streak_y)], fill=(0, 229, 255, 38), width=int(1.5*s))

x_cursor = start_x
letters_data = []

letters_data.append(('single', get_v_poly(x_cursor, base_y, letter_widths[0])))
x_cursor += letter_widths[0] + spacing
letters_data.append(('double', get_a_poly(x_cursor, base_y, letter_widths[1])))
x_cursor += letter_widths[1] + spacing
letters_data.append(('single', get_n_poly(x_cursor, base_y, letter_widths[2])))
x_cursor += letter_widths[2] + spacing
letters_data.append(('single', get_g_poly(x_cursor, base_y, letter_widths[3])))
x_cursor += letter_widths[3] + spacing
letters_data.append(('single', get_u_poly(x_cursor, base_y, letter_widths[4])))
x_cursor += letter_widths[4] + spacing
letters_data.append(('double', get_a_poly(x_cursor, base_y, letter_widths[5])))
x_cursor += letter_widths[5] + spacing
letters_data.append(('double', get_r_poly(x_cursor, base_y, letter_widths[6])))
x_cursor += letter_widths[6] + spacing
letters_data.append(('double', get_d_poly(x_cursor, base_y, letter_widths[7])))

for ltype, data in letters_data:
    if ltype == 'single':
        draw_chiseled_poly(data, (246, 249, 252, 255), (0, 229, 255, 255), shadow_col=(6, 18, 38, 220), width=3.5)
        glow_draw.polygon(data, outline=(0, 229, 255, 190), width=int(9*s))
    else:
        outer, inner = data
        draw_chiseled_poly(outer, (246, 249, 252, 255), (0, 229, 255, 255), shadow_col=(6, 18, 38, 220), width=3.5)
        draw.polygon(inner, fill=(0, 0, 0, 0), outline=(0, 229, 255, 255), width=int(2.8*s))
        glow_draw.polygon(outer, outline=(0, 229, 255, 190), width=int(9*s))
        glow_draw.polygon(inner, outline=(0, 229, 255, 190), width=int(4*s))

# Top "P R O J E C T"
proj_y = base_y - 70 * s
draw.line([(cx - total_w/2, proj_y + 12*s), (cx - 180*s, proj_y + 12*s)], fill=(0, 229, 255, 200), width=int(2.5*s))
draw.line([(cx + 180*s, proj_y + 12*s), (cx + total_w/2, proj_y + 12*s)], fill=(0, 229, 255, 200), width=int(2.5*s))

draw.polygon([(cx - 192*s, proj_y + 12*s), (cx - 184*s, proj_y + 6*s), (cx - 176*s, proj_y + 12*s), (cx - 184*s, proj_y + 18*s)], fill=(255, 179, 0, 255))
draw.polygon([(cx + 192*s, proj_y + 12*s), (cx + 184*s, proj_y + 6*s), (cx + 176*s, proj_y + 12*s), (cx + 184*s, proj_y + 18*s)], fill=(255, 179, 0, 255))

proj_chars = ["P", "R", "O", "J", "E", "C", "T"]
p_spacing = 42 * s
p_start_x = cx - (len(proj_chars) - 1) * p_spacing / 2.0
pH = 28 * s
pSW = 6 * s

for i, ch in enumerate(proj_chars):
    px = p_start_x + i * p_spacing
    py = proj_y - 4 * s
    if ch == "P":
        draw.line([(px - 8*s, py), (px - 8*s, py + pH)], fill=(0, 229, 255, 255), width=int(pSW))
        draw.polygon([(px - 8*s, py), (px + 8*s, py), (px + 8*s, py + pH*0.55), (px - 8*s, py + pH*0.55)], outline=(0, 229, 255, 255), width=int(pSW*0.7))
    elif ch == "R":
        draw.line([(px - 8*s, py), (px - 8*s, py + pH)], fill=(0, 229, 255, 255), width=int(pSW))
        draw.polygon([(px - 8*s, py), (px + 8*s, py), (px + 8*s, py + pH*0.5), (px - 8*s, py + pH*0.5)], outline=(0, 229, 255, 255), width=int(pSW*0.7))
        draw.line([(px - 4*s, py + pH*0.5), (px + 8*s, py + pH)], fill=(0, 229, 255, 255), width=int(pSW*0.8))
    elif ch == "O":
        draw.rectangle([px - 8*s, py, px + 8*s, py + pH], outline=(0, 229, 255, 255), width=int(pSW*0.7))
    elif ch == "J":
        draw.line([(px - 8*s, py), (px + 8*s, py)], fill=(0, 229, 255, 255), width=int(pSW*0.7))
        draw.line([(px + 3*s, py), (px + 3*s, py + pH - 6*s)], fill=(0, 229, 255, 255), width=int(pSW*0.7))
        draw.line([(px + 3*s, py + pH), (px - 8*s, py + pH)], fill=(0, 229, 255, 255), width=int(pSW*0.7))
    elif ch == "E":
        draw.line([(px - 8*s, py), (px - 8*s, py + pH)], fill=(0, 229, 255, 255), width=int(pSW))
        draw.line([(px - 8*s, py), (px + 8*s, py)], fill=(0, 229, 255, 255), width=int(pSW*0.7))
        draw.line([(px - 8*s, py + pH/2), (px + 4*s, py + pH/2)], fill=(0, 229, 255, 255), width=int(pSW*0.7))
        draw.line([(px - 8*s, py + pH), (px + 8*s, py + pH)], fill=(0, 229, 255, 255), width=int(pSW*0.7))
    elif ch == "C":
        draw.line([(px - 8*s, py), (px - 8*s, py + pH)], fill=(0, 229, 255, 255), width=int(pSW))
        draw.line([(px - 8*s, py), (px + 8*s, py)], fill=(0, 229, 255, 255), width=int(pSW*0.7))
        draw.line([(px - 8*s, py + pH), (px + 8*s, py + pH)], fill=(0, 229, 255, 255), width=int(pSW*0.7))
    elif ch == "T":
        draw.line([(px - 9*s, py), (px + 9*s, py)], fill=(0, 229, 255, 255), width=int(pSW*0.8))
        draw.line([(px, py), (px, py + pH)], fill=(0, 229, 255, 255), width=int(pSW))

# Bottom Tactical Subline Bar
sub_y = base_y + H_L + 36 * s
draw.line([(cx - total_w/2, sub_y), (cx + total_w/2, sub_y)], fill=(0, 229, 255, 180), width=int(2.5*s))
draw.line([(cx - total_w/2, sub_y + 8*s), (cx + total_w/2, sub_y + 8*s)], fill=(0, 229, 255, 60), width=int(1.2*s))

ch_y = sub_y + 24 * s
ch_w = 14 * s
for ci in range(-8, 9):
    c_pos = cx + ci * 48 * s
    draw.polygon([(c_pos - ch_w, ch_y - 6*s), (c_pos, ch_y), (c_pos - ch_w, ch_y + 6*s)], outline=(0, 229, 255, 140), width=int(1.5*s))

# Center gold warning tag: "404th STRIKE WING // AIRFRAME SEC-01"
badge_w = 260 * s
draw.rectangle([cx - badge_w, ch_y - 14*s, cx + badge_w, ch_y + 14*s], fill=(8, 25, 48, 240), outline=(255, 179, 0, 240), width=int(2*s))

# Subline stencil lettering inside the tag: "4 0 4 t h   W I N G   •   S E C - 0 1"
# Draw simple clean text lines inside badge
txt = "4 0 4 t h   V A N G U A R D   •   S T R I K E   W I N G"
try:
    # Try default sans font
    font = ImageFont.truetype("arial.ttf", int(14 * s))
except:
    font = ImageFont.load_default()

bbox = draw.textbbox((0, 0), txt, font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
draw.text((cx - tw/2, ch_y - th/2 - 2*s), txt, fill=(255, 215, 0, 255), font=font)

# Flanking brackets
lb_x = cx - total_w/2 - 50 * s
draw.polygon([
    (lb_x, base_y),
    (lb_x - 70*s, base_y + 35*s),
    (lb_x - 70*s, base_y + H_L - 35*s),
    (lb_x, base_y + H_L),
    (lb_x - 25*s, base_y + H_L - 25*s),
    (lb_x - 45*s, base_y + H_L - 40*s),
    (lb_x - 45*s, base_y + 40*s),
    (lb_x - 25*s, base_y + 25*s),
], fill=(13, 71, 161, 200), outline=(0, 229, 255, 255), width=int(2.5*s))
draw.line([(lb_x - 85*s, base_y + 20*s), (lb_x - 85*s, base_y + H_L - 20*s)], fill=(255, 179, 0, 220), width=int(3*s))

rb_x = cx + total_w/2 + 50 * s
draw.polygon([
    (rb_x, base_y),
    (rb_x + 70*s, base_y + 35*s),
    (rb_x + 70*s, base_y + H_L - 35*s),
    (rb_x, base_y + H_L),
    (rb_x + 25*s, base_y + H_L - 25*s),
    (rb_x + 45*s, base_y + H_L - 40*s),
    (rb_x + 45*s, base_y + 40*s),
    (rb_x + 25*s, base_y + 25*s),
], fill=(13, 71, 161, 200), outline=(0, 229, 255, 255), width=int(2.5*s))
draw.line([(rb_x + 85*s, base_y + 20*s), (rb_x + 85*s, base_y + H_L - 20*s)], fill=(255, 179, 0, 220), width=int(3*s))

glow_blurred = glow_img.filter(ImageFilter.GaussianBlur(radius=int(6 * s)))
final_img = Image.alpha_composite(glow_blurred, img)

out = final_img.resize((W, H), Image.Resampling.LANCZOS)

# Save main 2400x640 transparent PNG
out.save(os.path.join(OUTPUT_DIR, "project_vanguard_title.png"), "PNG")
out.save(os.path.join(r"godot_project/ui", "project_vanguard_title.png"), "PNG")

# Also save tight-cropped version (bounding box with 20px padding)
bbox_crop = out.getbbox()
if bbox_crop:
    pad = 20
    crop_rect = (
        max(0, bbox_crop[0] - pad),
        max(0, bbox_crop[1] - pad),
        min(W, bbox_crop[2] + pad),
        min(H, bbox_crop[3] + pad)
    )
    cropped_logo = out.crop(crop_rect)
    cropped_logo.save(os.path.join(OUTPUT_DIR, "project_vanguard_title_cropped.png"), "PNG")
    cropped_logo.save(os.path.join(r"godot_project/ui", "project_vanguard_title_cropped.png"), "PNG")
    print(f"Saved cropped version: {cropped_logo.size}")

print("Saved updated Project Vanguard title.")
