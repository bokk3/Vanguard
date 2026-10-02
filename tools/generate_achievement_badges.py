import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIRS = [
    os.path.join(PROJECT_ROOT, "godot_project", "ui", "badges"),
    os.path.join(PROJECT_ROOT, "website", "public", "images", "badges"),
]
for d in OUTPUT_DIRS:
    os.makedirs(d, exist_ok=True)

SIZE = 512
SCALE = 2
CANVAS_SIZE = SIZE * SCALE
CENTER = CANVAS_SIZE // 2

def draw_star(draw, cx, cy, r_outer, r_inner, points=5, fill=(255, 215, 0), outline=None, width=1, rot_offset=-math.pi/2):
    pts = []
    angle_step = math.pi / points
    for i in range(points * 2):
        r = r_outer if i % 2 == 0 else r_inner
        ang = rot_offset + i * angle_step
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    draw.polygon(pts, fill=fill, outline=outline, width=width)

def draw_shield(draw, cx, cy, w, h, fill, outline, outline_w=4):
    pts = [
        (cx - w // 2, cy - h // 2),
        (cx + w // 2, cy - h // 2),
        (cx + w // 2, cy + h // 6),
        (cx, cy + h // 2),
        (cx - w // 2, cy + h // 6)
    ]
    draw.polygon(pts, fill=fill, outline=outline, width=outline_w)

def draw_wings(draw, cx, cy, wing_span, wing_height, color):
    # Left wing
    left_pts = [
        (cx - 20, cy),
        (cx - wing_span // 2, cy - wing_height),
        (cx - wing_span, cy - wing_height // 2),
        (cx - wing_span * 0.7, cy + wing_height // 3),
        (cx - wing_span * 0.4, cy + wing_height // 2),
        (cx - 10, cy + 10)
    ]
    draw.polygon(left_pts, fill=color)
    # Right wing
    right_pts = [
        (cx + 20, cy),
        (cx + wing_span // 2, cy - wing_height),
        (cx + wing_span, cy - wing_height // 2),
        (cx + wing_span * 0.7, cy + wing_height // 3),
        (cx + wing_span * 0.4, cy + wing_height // 2),
        (cx + 10, cy + 10)
    ]
    draw.polygon(right_pts, fill=color)

def draw_fighter_jet(draw, cx, cy, size, color, rot=0):
    # Delta fighter silhouette
    base_pts = [
        (0, -size),            # Nose tip
        (size * 0.25, -size * 0.3),
        (size * 0.9, size * 0.4),  # Wing tip R
        (size * 0.4, size * 0.5),
        (size * 0.2, size * 0.8),  # Tail R
        (0, size * 0.65),           # Thruster
        (-size * 0.2, size * 0.8), # Tail L
        (-size * 0.4, size * 0.5),
        (-size * 0.9, size * 0.4), # Wing tip L
        (-size * 0.25, -size * 0.3)
    ]
    # Rotate points
    transformed = []
    cos_r = math.cos(rot)
    sin_r = math.sin(rot)
    for px, py in base_pts:
        tx = cx + px * cos_r - py * sin_r
        ty = cy + px * sin_r + py * cos_r
        transformed.append((tx, ty))
    draw.polygon(transformed, fill=color)

def create_base_badge(primary_color, rim_color, bg_dark=(15, 18, 26)):
    img = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    r_outer = int(CENTER * 0.86)
    r_rim = int(CENTER * 0.82)
    r_inner = int(CENTER * 0.76)
    
    # Outer drop glow / shadow
    for i in range(12):
        alpha = int(35 * (1.0 - i / 12.0))
        draw.ellipse([CENTER - r_outer - i*2, CENTER - r_outer - i*2, CENTER + r_outer + i*2, CENTER + r_outer + i*2], 
                     fill=None, outline=(*rim_color[:3], alpha), width=2)
                     
    # Metallic Outer Bezel
    draw.ellipse([CENTER - r_outer, CENTER - r_outer, CENTER + r_outer, CENTER + r_outer], fill=rim_color)
    # Inner Bezel groove
    draw.ellipse([CENTER - r_rim, CENTER - r_rim, CENTER + r_rim, CENTER + r_rim], fill=(30, 36, 48))
    # Dark carbon interior disc
    draw.ellipse([CENTER - r_inner, CENTER - r_inner, CENTER + r_inner, CENTER + r_inner], fill=bg_dark)
    
    # Subtle radial tick marks / compass bearings
    for deg in range(0, 360, 30):
        rad = math.radians(deg)
        t_len = 16 if deg % 90 == 0 else 8
        p1 = (CENTER + (r_inner - 4) * math.cos(rad), CENTER + (r_inner - 4) * math.sin(rad))
        p2 = (CENTER + (r_inner - 4 - t_len) * math.cos(rad), CENTER + (r_inner - 4 - t_len) * math.sin(rad))
        draw.line([p1, p2], fill=(*primary_color[:3], 180), width=3)
        
    return img, draw, r_inner

def finalize_badge(img, filename):
    # Downscale for super-sampled anti-aliasing with optimized PNG compression
    final_img = img.resize((SIZE // 2, SIZE // 2), Image.Resampling.LANCZOS)
    for out_dir in OUTPUT_DIRS:
        target_path = os.path.join(out_dir, filename)
        final_img.save(target_path, "PNG", optimize=True)
    print(f"Generated badge: {filename} (256x256) -> {len(OUTPUT_DIRS)} targets")

# =============================================================================
# 1. FIRST_SORTIE: Novice Pilot Wings & Supersonic Delta Climb
# =============================================================================
def gen_first_sortie():
    img, draw, r = create_base_badge((0, 215, 255), (200, 215, 230), bg_dark=(10, 15, 22))
    # Silver flight wings
    draw_wings(draw, CENTER, CENTER + 60, int(r * 1.05), int(r * 0.45), (190, 205, 220))
    draw_wings(draw, CENTER, CENTER + 55, int(r * 0.95), int(r * 0.38), (230, 240, 255))
    # Supersonic delta fighter climbing up
    draw_fighter_jet(draw, CENTER, CENTER - 20, int(r * 0.55), (0, 220, 255))
    draw_fighter_jet(draw, CENTER, CENTER - 20, int(r * 0.42), (255, 255, 255))
    # Golden Commissioning Star on top
    draw_star(draw, CENTER, CENTER - int(r * 0.58), 34, 16, fill=(255, 200, 0))
    finalize_badge(img, "badge_first_sortie.png")

# =============================================================================
# 2. ACE_INTERCEPTOR: 25 Kills - Crossed Lightning Bolts & Dual Combat Stars
# =============================================================================
def gen_ace_interceptor():
    img, draw, r = create_base_badge((255, 170, 0), (255, 190, 30), bg_dark=(22, 14, 8))
    # Crossed lightning bolts
    def draw_bolt(angle):
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)
        bolt_pts = [(-20, -r*0.6), (15, -r*0.1), (-10, -r*0.05), (25, r*0.6), (-5, r*0.1), (15, r*0.05)]
        pts = [(CENTER + px*cos_a - py*sin_a, CENTER + px*sin_a + py*cos_a) for px, py in bolt_pts]
        draw.polygon(pts, fill=(255, 215, 0))
    draw_bolt(math.radians(-35))
    draw_bolt(math.radians(35))
    
    # Interceptor silhouette
    draw_fighter_jet(draw, CENTER, CENTER, int(r * 0.5), (255, 255, 255))
    draw_fighter_jet(draw, CENTER, CENTER, int(r * 0.38), (255, 160, 0))
    
    # Twin Ace Stars
    draw_star(draw, CENTER - int(r * 0.5), CENTER + int(r * 0.3), 26, 12, fill=(255, 225, 50))
    draw_star(draw, CENTER + int(r * 0.5), CENTER + int(r * 0.3), 26, 12, fill=(255, 225, 50))
    finalize_badge(img, "badge_ace_interceptor.png")

# =============================================================================
# 3. WAR_GOD_OF_SOL: 100 Kills - Golden Sunburst Crown & Imperial Crest
# =============================================================================
def gen_war_god_of_sol():
    img, draw, r = create_base_badge((255, 215, 0), (255, 215, 0), bg_dark=(25, 18, 5))
    # Radiating golden coronal sunburst rays
    for deg in range(0, 360, 15):
        rad = math.radians(deg)
        r_out = r * 0.72 if deg % 30 == 0 else r * 0.58
        p1 = (CENTER + r * 0.3 * math.cos(rad), CENTER + r * 0.3 * math.sin(rad))
        p2 = (CENTER + r_out * math.cos(rad), CENTER + r_out * math.sin(rad))
        draw.line([p1, p2], fill=(255, 200, 0, 190), width=6 if deg % 30 == 0 else 3)
        
    # Central Imperial Ace Shield
    draw_shield(draw, CENTER, CENTER + 10, int(r * 0.85), int(r * 0.95), fill=(40, 28, 10), outline=(255, 220, 50), outline_w=6)
    # Crowned laurel top
    draw_star(draw, CENTER, CENTER - int(r * 0.25), 45, 22, fill=(255, 230, 80))
    draw_star(draw, CENTER - 55, CENTER - int(r * 0.18), 30, 14, fill=(255, 200, 0))
    draw_star(draw, CENTER + 55, CENTER - int(r * 0.18), 30, 14, fill=(255, 200, 0))
    
    # 100 Kills Roman Numeral or Ace Emblem
    draw.polygon([(CENTER, CENTER + 70), (CENTER - 45, CENTER), (CENTER + 45, CENTER)], fill=(255, 215, 0))
    draw.polygon([(CENTER, CENTER + 55), (CENTER - 30, CENTER + 5), (CENTER + 30, CENTER + 5)], fill=(25, 18, 5))
    finalize_badge(img, "badge_war_god_of_sol.png")

# =============================================================================
# 4. GHOST_PROTOCOL: Zero Damage - Hexagonal Kinetic Shield & Stealth Phantom
# =============================================================================
def gen_ghost_protocol():
    img, draw, r = create_base_badge((160, 80, 255), (140, 70, 240), bg_dark=(12, 8, 24))
    # Hexagonal energy barrier rings
    hex_pts = []
    for i in range(6):
        ang = -math.pi/2 + i * (math.pi / 3)
        hex_pts.append((CENTER + r * 0.65 * math.cos(ang), CENTER + r * 0.65 * math.sin(ang)))
    draw.polygon(hex_pts, fill=None, outline=(180, 100, 255), width=6)
    
    # Inner energy mesh
    inner_hex = []
    for i in range(6):
        ang = -math.pi/2 + i * (math.pi / 3)
        inner_hex.append((CENTER + r * 0.52 * math.cos(ang), CENTER + r * 0.52 * math.sin(ang)))
    draw.polygon(inner_hex, fill=(24, 15, 45), outline=(130, 60, 220), width=4)
    
    # Stealth delta fighter in phantom silhouette
    draw_fighter_jet(draw, CENTER, CENTER, int(r * 0.44), (200, 140, 255))
    draw_fighter_jet(draw, CENTER, CENTER, int(r * 0.32), (15, 10, 25))
    # Kinetic shield spark
    draw_star(draw, CENTER, CENTER - int(r * 0.45), 24, 10, fill=(220, 170, 255))
    finalize_badge(img, "badge_ghost_protocol.png")

# =============================================================================
# 5. CAMPAIGN_HERO: Mission 05 Silent Orbit - Orbital Sphere & Gold Victory Star
# =============================================================================
def gen_campaign_hero():
    img, draw, r = create_base_badge((0, 220, 255), (0, 200, 240), bg_dark=(8, 16, 28))
    # Orbiting planetary disc
    draw.ellipse([CENTER - int(r*0.42), CENTER - int(r*0.42), CENTER + int(r*0.42), CENTER + int(r*0.42)], 
                 fill=(15, 35, 60), outline=(0, 210, 255), width=5)
                 
    # Elliptical orbital trajectory ring
    draw.ellipse([CENTER - int(r*0.75), CENTER - int(r*0.3), CENTER + int(r*0.75), CENTER + int(r*0.3)], 
                 fill=None, outline=(255, 215, 0), width=4)
                 
    # Triumphant gold victory star at zenith
    draw_star(draw, CENTER, CENTER - int(r * 0.42), 48, 22, fill=(255, 215, 0), outline=(255, 255, 255), width=2)
    # Orbiting satellite node
    draw.ellipse([CENTER + int(r*0.62) - 12, CENTER - 12, CENTER + int(r*0.62) + 12, CENTER + 12], fill=(0, 255, 220))
    finalize_badge(img, "badge_campaign_hero.png")

# =============================================================================
# 6. FLEET_DEDICATION: 7-Day Streak - Arched Constellation & Winged Shield
# =============================================================================
def gen_fleet_dedication():
    img, draw, r = create_base_badge((50, 230, 120), (40, 200, 100), bg_dark=(8, 22, 16))
    # Winged shield
    draw_wings(draw, CENTER, CENTER + 40, int(r * 0.95), int(r * 0.38), (30, 90, 60))
    draw_shield(draw, CENTER, CENTER + 30, int(r * 0.65), int(r * 0.7), fill=(14, 40, 28), outline=(50, 230, 120), outline_w=5)
    
    # 7 Golden Stars along upper arch
    num_stars = 7
    start_deg = -150
    end_deg = -30
    step = (end_deg - start_deg) / (num_stars - 1)
    for i in range(num_stars):
        ang = math.radians(start_deg + i * step)
        sx = CENTER + int(r * 0.68 * math.cos(ang))
        sy = CENTER + int(r * 0.68 * math.sin(ang))
        r_out = 26 if i == 3 else 18  # Center 4th star is biggest
        draw_star(draw, sx, sy, r_out, r_out // 2, fill=(255, 220, 50))
        
    # Central checkmark / numeral '7'
    draw.polygon([(CENTER - 25, CENTER + 5), (CENTER + 25, CENTER + 5), (CENTER - 5, CENTER + 55), (CENTER - 20, CENTER + 55), (CENTER + 10, CENTER + 20), (CENTER - 25, CENTER + 20)], fill=(50, 230, 120))
    finalize_badge(img, "badge_fleet_dedication.png")

# =============================================================================
# 7. LUCKY_STRIKE: Wheel Jackpot - Concentric Bullseye & Starburst
# =============================================================================
def gen_lucky_strike():
    img, draw, r = create_base_badge((255, 200, 0), (255, 180, 20), bg_dark=(24, 18, 6))
    # Concentric target reticle rings
    for radius in [int(r*0.65), int(r*0.46), int(r*0.28)]:
        draw.ellipse([CENTER - radius, CENTER - radius, CENTER + radius, CENTER + radius], 
                     fill=None, outline=(255, 190, 0, 180), width=4)
                     
    # Crosshairs
    draw.line([(CENTER - int(r*0.7), CENTER), (CENTER + int(r*0.7), CENTER)], fill=(255, 215, 0), width=3)
    draw.line([(CENTER, CENTER - int(r*0.7)), (CENTER, CENTER + int(r*0.7))], fill=(255, 215, 0), width=3)
    
    # Radiating 8-point gold jackpot star
    draw_star(draw, CENTER, CENTER, int(r * 0.35), int(r * 0.14), points=8, fill=(255, 235, 60), outline=(255, 255, 255), width=2)
    # Diamond sparks in 4 corners
    for angle in [45, 135, 225, 315]:
        rad = math.radians(angle)
        sx = CENTER + int(r * 0.52 * math.cos(rad))
        sy = CENTER + int(r * 0.52 * math.sin(rad))
        draw_star(draw, sx, sy, 18, 8, points=4, fill=(255, 255, 200))
    finalize_badge(img, "badge_lucky_strike.png")

# =============================================================================
# 8. PVP_GLADIATOR: Dogfight Victory - Crossed Heavy Autocannons & Combat Crest
# =============================================================================
def gen_pvp_gladiator():
    img, draw, r = create_base_badge((240, 60, 60), (220, 50, 50), bg_dark=(25, 8, 8))
    # Crossed heavy laser cannon barrels
    def draw_cannon(angle):
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)
        barrel_pts = [
            (-12, -r*0.65), (12, -r*0.65), (12, r*0.65), (18, r*0.65), (18, r*0.75),
            (-18, r*0.75), (-18, r*0.65), (-12, r*0.65)
        ]
        pts = [(CENTER + px*cos_a - py*sin_a, CENTER + px*sin_a + py*cos_a) for px, py in barrel_pts]
        draw.polygon(pts, fill=(180, 190, 205), outline=(255, 70, 70), width=2)
    draw_cannon(math.radians(-40))
    draw_cannon(math.radians(40))
    
    # Combat shield
    draw_shield(draw, CENTER, CENTER, int(r * 0.72), int(r * 0.82), fill=(45, 14, 14), outline=(255, 70, 70), outline_w=6)
    # Aggressive chevron eagle emblem
    draw_fighter_jet(draw, CENTER, CENTER, int(r * 0.38), (255, 255, 255))
    draw_fighter_jet(draw, CENTER, CENTER, int(r * 0.28), (240, 50, 50))
    finalize_badge(img, "badge_pvp_gladiator.png")

# =============================================================================
# 9. ARSENAL_OVERLORD: Tier III Upgrade - Heavy Ordnance & Triple Chevrons
# =============================================================================
def gen_arsenal_overlord():
    img, draw, r = create_base_badge((255, 160, 0), (255, 180, 0), bg_dark=(20, 14, 6))
    # Triple golden chevrons (Rank / Overlord)
    for i, offset_y in enumerate([-60, 0, 60]):
        cy = CENTER + offset_y
        chev_pts = [
            (CENTER, cy - 40),
            (CENTER + int(r * 0.55), cy + 10),
            (CENTER + int(r * 0.42), cy + 30),
            (CENTER, cy - 10),
            (CENTER - int(r * 0.42), cy + 30),
            (CENTER - int(r * 0.55), cy + 10)
        ]
        col = (255, 220, 40) if i == 0 else ((255, 180, 20) if i == 1 else (230, 140, 0))
        draw.polygon(chev_pts, fill=col, outline=(255, 255, 200), width=2)
        
    # Top diamond power capacitor
    draw_star(draw, CENTER, CENTER - int(r * 0.55), 26, 12, points=4, fill=(255, 240, 100))
    finalize_badge(img, "badge_arsenal_overlord.png")

# =============================================================================
# 10. SOLAR_FASHION: Livery Unlocked - Custom Iridescent Aerofoil Wings
# =============================================================================
def gen_solar_fashion():
    img, draw, r = create_base_badge((240, 80, 160), (230, 70, 150), bg_dark=(20, 8, 20))
    # Dual-tone aerodynamic stripes
    draw_wings(draw, CENTER, CENTER + 30, int(r * 1.05), int(r * 0.45), (255, 60, 140))
    draw_wings(draw, CENTER, CENTER + 20, int(r * 0.85), int(r * 0.35), (255, 180, 50))
    # Aerodynamic fighter hull
    draw_fighter_jet(draw, CENTER, CENTER - 10, int(r * 0.5), (255, 255, 255))
    draw_fighter_jet(draw, CENTER, CENTER - 10, int(r * 0.36), (230, 40, 120))
    
    # Radiant color diamond star
    draw_star(draw, CENTER, CENTER - int(r * 0.52), 32, 14, fill=(255, 215, 0))
    finalize_badge(img, "badge_solar_fashion.png")

# =============================================================================
# 11. KINETIC_ACE: All 8 Agility Flight Trials Completed
# =============================================================================
def gen_kinetic_ace():
    img, draw, r = create_base_badge((255, 145, 0), (255, 185, 30), bg_dark=(18, 12, 10))
    # Slalom Gate Pylons (Left & Right vertical high-g markers)
    pylon_l = [(CENTER - int(r*0.62), CENTER + int(r*0.55)), (CENTER - int(r*0.48), CENTER - int(r*0.55)), (CENTER - int(r*0.40), CENTER - int(r*0.50)), (CENTER - int(r*0.54), CENTER + int(r*0.55))]
    pylon_r = [(CENTER + int(r*0.62), CENTER + int(r*0.55)), (CENTER + int(r*0.48), CENTER - int(r*0.55)), (CENTER + int(r*0.40), CENTER - int(r*0.50)), (CENTER + int(r*0.54), CENTER + int(r*0.55))]
    draw.polygon(pylon_l, fill=(255, 120, 0), outline=(255, 220, 80), width=2)
    draw.polygon(pylon_r, fill=(255, 120, 0), outline=(255, 220, 80), width=2)
    
    # Glowing Holographic Gate Ring
    draw.ellipse([CENTER - int(r*0.55), CENTER - int(r*0.25), CENTER + int(r*0.55), CENTER + int(r*0.45)], fill=None, outline=(255, 195, 0, 200), width=4)
    
    # Supersonic knife-edge banking fighter slicing through the apex
    draw_fighter_jet(draw, CENTER, CENTER + 5, int(r * 0.48), (255, 255, 255), rot=math.radians(35))
    draw_fighter_jet(draw, CENTER, CENTER + 5, int(r * 0.35), (255, 140, 0), rot=math.radians(35))
    
    # Kinetic commission star at zenith
    draw_star(draw, CENTER, CENTER - int(r * 0.58), 34, 16, fill=(255, 215, 0), outline=(255, 255, 255), width=2)
    finalize_badge(img, "badge_kinetic_ace.png")

# =============================================================================
# 12. GOLDEN_VECTOR: Gold / Ace Standard Across All 8 Trials
# =============================================================================
def gen_golden_vector():
    img, draw, r = create_base_badge((255, 215, 0), (255, 230, 80), bg_dark=(26, 20, 4))
    # Radiating golden coronal velocity lines
    for deg in range(0, 360, 20):
        rad = math.radians(deg)
        p1 = (CENTER + int(r * 0.45 * math.cos(rad)), CENTER + int(r * 0.45 * math.sin(rad)))
        p2 = (CENTER + int(r * 0.72 * math.cos(rad)), CENTER + int(r * 0.72 * math.sin(rad)))
        draw.line([p1, p2], fill=(255, 210, 40, 160), width=3)
        
    # Dual polished gold laurel wings
    draw_wings(draw, CENTER, CENTER + 45, int(r * 1.05), int(r * 0.42), (230, 175, 10))
    draw_wings(draw, CENTER, CENTER + 38, int(r * 0.95), int(r * 0.36), (255, 225, 60))
    
    # Central Golden Apex Delta Vector
    draw_fighter_jet(draw, CENTER, CENTER - 10, int(r * 0.52), (255, 255, 255))
    draw_fighter_jet(draw, CENTER, CENTER - 10, int(r * 0.38), (255, 200, 0))
    
    # Tri-Star Golden Crown (Ace standards)
    draw_star(draw, CENTER, CENTER - int(r * 0.55), 36, 16, fill=(255, 240, 80))
    draw_star(draw, CENTER - 58, CENTER - int(r * 0.38), 26, 12, fill=(255, 215, 0))
    draw_star(draw, CENTER + 58, CENTER - int(r * 0.38), 26, 12, fill=(255, 215, 0))
    finalize_badge(img, "badge_golden_vector.png")

# =============================================================================
# 13. AVIONICS_LEGEND: 2,500+ Avionics Expertise Score
# =============================================================================
def gen_avionics_legend():
    img, draw, r = create_base_badge((0, 240, 255), (140, 230, 255), bg_dark=(8, 18, 28))
    # Precision telemetry compass rose & concentric bullseye rings
    for radius in [int(r*0.68), int(r*0.50), int(r*0.30)]:
        draw.ellipse([CENTER - radius, CENTER - radius, CENTER + radius, CENTER + radius], fill=None, outline=(0, 220, 255, 160), width=3)
        
    # Micro compass ticks (every 15 deg)
    for deg in range(0, 360, 15):
        rad = math.radians(deg)
        l_in = r * 0.65 if deg % 45 == 0 else r * 0.69
        p1 = (CENTER + int(l_in * math.cos(rad)), CENTER + int(l_in * math.sin(rad)))
        p2 = (CENTER + int(r * 0.72 * math.cos(rad)), CENTER + int(r * 0.72 * math.sin(rad)))
        draw.line([p1, p2], fill=(0, 240, 255), width=2 if deg % 45 != 0 else 4)
        
    # Swept supersonic cyber wings
    draw_wings(draw, CENTER, CENTER + 25, int(r * 0.90), int(r * 0.35), (0, 160, 200))
    draw_wings(draw, CENTER, CENTER + 20, int(r * 0.80), int(r * 0.30), (0, 240, 255))
    
    # Diamond Avionics Legend Star
    draw_star(draw, CENTER, CENTER - int(r * 0.45), 42, 18, points=4, fill=(255, 255, 255), outline=(0, 240, 255), width=3)
    finalize_badge(img, "badge_avionics_legend.png")

# =============================================================================
# 14. CHRONO_MASTER: Ace Standard Time Clocked on Flight Challenge
# =============================================================================
def gen_chrono_master():
    img, draw, r = create_base_badge((50, 240, 140), (255, 200, 40), bg_dark=(6, 22, 16))
    # Outer Chronometer Dial Ticks (60-second perimeter scale)
    for s in range(60):
        rad = math.radians(s * 6 - 90)
        t_len = 22 if s % 5 == 0 else 10
        p1 = (CENTER + int((r * 0.72 - t_len) * math.cos(rad)), CENTER + int((r * 0.72 - t_len) * math.sin(rad)))
        p2 = (CENTER + int(r * 0.72 * math.cos(rad)), CENTER + int(r * 0.72 * math.sin(rad)))
        draw.line([p1, p2], fill=(50, 240, 140, 220) if s % 5 == 0 else (40, 180, 100, 140), width=3 if s % 5 == 0 else 1)
        
    # Stopwatch Needle pointing at supersonic record mark (-45 deg)
    needle_ang = math.radians(-50)
    np1 = (CENTER - int(25 * math.cos(needle_ang)), CENTER - int(25 * math.sin(needle_ang)))
    np2 = (CENTER + int(r * 0.65 * math.cos(needle_ang)), CENTER + int(r * 0.65 * math.sin(needle_ang)))
    draw.line([np1, np2], fill=(255, 220, 50), width=5)
    draw.ellipse([CENTER - 14, CENTER - 14, CENTER + 14, CENTER + 14], fill=(255, 220, 50), outline=(255, 255, 255), width=2)
    
    # Central Mach Sprint Delta Silhouette
    draw_fighter_jet(draw, CENTER + 20, CENTER + 20, int(r * 0.40), (50, 240, 140))
    draw_fighter_jet(draw, CENTER + 20, CENTER + 20, int(r * 0.28), (255, 255, 255))
    
    # Chrono Star at 12 o'clock
    draw_star(draw, CENTER, CENTER - int(r * 0.55), 26, 12, fill=(255, 215, 0))
    finalize_badge(img, "badge_chrono_master.png")

if __name__ == "__main__":
    import time
    from concurrent.futures import ThreadPoolExecutor

    t0 = time.time()
    badge_generators = [
        gen_first_sortie,
        gen_ace_interceptor,
        gen_war_god_of_sol,
        gen_ghost_protocol,
        gen_campaign_hero,
        gen_fleet_dedication,
        gen_lucky_strike,
        gen_pvp_gladiator,
        gen_arsenal_overlord,
        gen_solar_fashion,
        gen_kinetic_ace,
        gen_golden_vector,
        gen_avionics_legend,
        gen_chrono_master,
    ]
    print(f"Generating {len(badge_generators)} tactical achievement badges for Project Vanguard...")
    with ThreadPoolExecutor(max_workers=min(8, os.cpu_count() or 4)) as executor:
        list(executor.map(lambda fn: fn(), badge_generators))
        
    elapsed = time.time() - t0
    print(f"All {len(badge_generators)} badges generated & optimized successfully in {elapsed:.2f}s!")

