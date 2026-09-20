import os
import math
from PIL import Image, ImageDraw, ImageFont

# Canvas dimensions (supersampled 2x for razor-sharp vector clarity)
WIDTH, HEIGHT = 640, 360
SCALE = 2
SW, SH = WIDTH * SCALE, HEIGHT * SCALE

OUT_DIRS = [
    os.path.join(os.path.dirname(__file__), "..", "godot_project", "ui"),
    os.path.join(os.path.dirname(__file__), "..", "docs", "lore", "images")
]

def get_font(size):
    try:
        return ImageFont.truetype("arial.ttf", size * SCALE)
    except Exception:
        try:
            return ImageFont.truetype("segoeui.ttf", size * SCALE)
        except Exception:
            return ImageFont.load_default()

def draw_hud_frame(draw, title, subtitle, tag_color, border_color=(0, 210, 255, 200)):
    # Outer HUD bracket corners
    pad = 20 * SCALE
    cw = 30 * SCALE
    # Dark semi-transparent tactical backdrop
    draw.rounded_rectangle([pad, pad, SW - pad, SH - pad], radius=10 * SCALE, fill=(6, 14, 24, 230), outline=border_color, width=2 * SCALE)
    
    # Grid lines across background
    for x in range(pad + 40 * SCALE, SW - pad, 40 * SCALE):
        draw.line([(x, pad), (x, SH - pad)], fill=(0, 180, 230, 25), width=1 * SCALE)
    for y in range(pad + 40 * SCALE, SH - pad, 40 * SCALE):
        draw.line([(pad, y), (SW - pad, y)], fill=(0, 180, 230, 25), width=1 * SCALE)
        
    # Corner brackets (military style)
    c_len = 25 * SCALE
    thick = 3 * SCALE
    # TL
    draw.line([(pad, pad + c_len), (pad, pad), (pad + c_len, pad)], fill=tag_color, width=thick)
    # TR
    draw.line([(SW - pad - c_len, pad), (SW - pad, pad), (SW - pad, pad + c_len)], fill=tag_color, width=thick)
    # BL
    draw.line([(pad, SH - pad - c_len), (pad, SH - pad), (pad + c_len, SH - pad)], fill=tag_color, width=thick)
    # BR
    draw.line([(SW - pad - c_len, SH - pad), (SW - pad, SH - pad), (SW - pad, SH - pad - c_len)], fill=tag_color, width=thick)
    
    # Title bar
    f_title = get_font(14)
    f_sub = get_font(10)
    draw.text((pad + 18 * SCALE, pad + 14 * SCALE), title, fill=(255, 255, 255, 255), font=f_title)
    draw.text((pad + 18 * SCALE, pad + 34 * SCALE), subtitle, fill=tag_color, font=f_sub)

def create_card_m01():
    img = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = 20 * SCALE
    
    draw_hud_frame(draw, "OPERATION: CLOUDBURST [M-01]", "THEATER: APEX-ZERO CLOUD CORRIDOR // SENSORS ARMED", (0, 229, 255, 240))
    
    # Storm cloud layers (layered translucent silhouettes)
    cx, cy = SW // 2, SH // 2 + 30 * SCALE
    for r in range(120 * SCALE, 30 * SCALE, -25 * SCALE):
        draw.ellipse([cx - r*2.2, cy + 30*SCALE - r*0.4, cx + r*2.2, cy + 120*SCALE + r*0.6], fill=(16, 32, 52, 140))
    
    # 360 Polar Radar Disc
    radar_center = (SW // 2, SH // 2 + 10 * SCALE)
    radar_radius = 85 * SCALE
    for rad in [25 * SCALE, 55 * SCALE, 85 * SCALE]:
        draw.ellipse([radar_center[0] - rad, radar_center[1] - rad, radar_center[0] + rad, radar_center[1] + rad],
                     outline=(0, 229, 255, 70), width=1 * SCALE)
    draw.line([(radar_center[0] - radar_radius, radar_center[1]), (radar_center[0] + radar_radius, radar_center[1])], fill=(0, 229, 255, 60), width=1 * SCALE)
    draw.line([(radar_center[0], radar_center[1] - radar_radius), (radar_center[0], radar_center[1] + radar_radius)], fill=(0, 229, 255, 60), width=1 * SCALE)
    
    # Sweep Line
    sweep_angle = math.radians(42)
    sx = radar_center[0] + math.cos(sweep_angle) * radar_radius
    sy = radar_center[1] - math.sin(sweep_angle) * radar_radius
    draw.line([radar_center, (sx, sy)], fill=(0, 255, 200, 200), width=2 * SCALE)
    
    # 4 Hostile Drone Contacts (Diamond blips with bracket reticles)
    blips = [
        (radar_center[0] + 45 * SCALE, radar_center[1] - 40 * SCALE),
        (radar_center[0] - 60 * SCALE, radar_center[1] - 25 * SCALE),
        (radar_center[0] + 35 * SCALE, radar_center[1] + 50 * SCALE),
        (radar_center[0] - 40 * SCALE, radar_center[1] + 35 * SCALE)
    ]
    for i, (bx, by) in enumerate(blips):
        bs = 6 * SCALE
        draw.polygon([(bx, by - bs), (bx + bs, by), (bx, by + bs), (bx - bs, by)], fill=(255, 60, 60, 230))
        # Lock reticle brackets
        rb = 12 * SCALE
        draw.line([(bx - rb, by - rb), (bx - rb + 4*SCALE, by - rb)], fill=(255, 60, 60, 200), width=1*SCALE)
        draw.line([(bx - rb, by - rb), (bx - rb, by - rb + 4*SCALE)], fill=(255, 60, 60, 200), width=1*SCALE)
        draw.line([(bx + rb, by + rb), (bx + rb - 4*SCALE, by + rb)], fill=(255, 60, 60, 200), width=1*SCALE)
        draw.line([(bx + rb, by + rb), (bx + rb, by + rb - 4*SCALE)], fill=(255, 60, 60, 200), width=1*SCALE)
    
    # Vanguard 1 central chevron
    vx, vy = radar_center
    draw.polygon([(vx, vy - 10 * SCALE), (vx + 7 * SCALE, vy + 8 * SCALE), (vx, vy + 4 * SCALE), (vx - 7 * SCALE, vy + 8 * SCALE)],
                 fill=(0, 255, 220, 255))
    
    # Tactical Telemetry readouts at bottom
    f_info = get_font(9)
    draw.text((pad + 18 * SCALE, SH - pad - 26 * SCALE), "ALT: 2,400M // AIRSPEED: 180 M/S // ORDNANCE: 4x VPSM-01 // HOSTILES: 4 TD-X",
              fill=(0, 229, 255, 220), font=f_info)
    
    return img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

def create_card_m02():
    img = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = 20 * SCALE
    
    draw_hud_frame(draw, "OPERATION: IRON CANYON [M-02]", "THEATER: THE RED SINKS // TERRAIN MASKING RUN (<120M)", (255, 120, 40, 240))
    
    # Red Sinks Canyon terrain jagged polygons
    cliff_l = [(pad, SH - pad - 40 * SCALE), (140 * SCALE, SH - pad - 90 * SCALE), (220 * SCALE, SH - pad - 60 * SCALE),
               (280 * SCALE, SH - pad - 120 * SCALE), (280 * SCALE, SH - pad), (pad, SH - pad)]
    cliff_r = [(SW - pad, SH - pad - 30 * SCALE), (SW - 130 * SCALE, SH - pad - 100 * SCALE), (SW - 200 * SCALE, SH - pad - 70 * SCALE),
               (SW - 270 * SCALE, SH - pad - 130 * SCALE), (SW - 270 * SCALE, SH - pad), (SW - pad, SH - pad)]
    draw.polygon(cliff_l, fill=(35, 16, 20, 220), outline=(255, 80, 40, 160), width=2 * SCALE)
    draw.polygon(cliff_r, fill=(35, 16, 20, 220), outline=(255, 80, 40, 160), width=2 * SCALE)
    
    # Canyon Floor wireframe grid
    floor_y = SH - pad - 30 * SCALE
    draw.line([(pad, floor_y), (SW - pad, floor_y)], fill=(255, 90, 40, 100), width=2 * SCALE)
    for x in range(pad + 30 * SCALE, SW - pad, 35 * SCALE):
        draw.line([(x, floor_y), (x + 10 * SCALE, SH - pad)], fill=(255, 80, 40, 50), width=1 * SCALE)
        
    # Altitude Danger Ceiling (Dotted Red line at 120m)
    ceil_y = SH // 2 - 10 * SCALE
    dash = 10 * SCALE
    gap = 8 * SCALE
    cur_x = pad + 10 * SCALE
    while cur_x < SW - pad - 10 * SCALE:
        draw.line([(cur_x, ceil_y), (min(cur_x + dash, SW - pad - 10 * SCALE), ceil_y)], fill=(255, 40, 40, 220), width=2 * SCALE)
        cur_x += dash + gap
    f_warn = get_font(9)
    draw.text((SW // 2 - 90 * SCALE, ceil_y - 18 * SCALE), "▲ SAM RADAR LOCK CEILING: 120M ▲", fill=(255, 60, 60, 240), font=f_warn)
    
    # 3 Jamming Relays (Towers with pulsing red radio wave arcs)
    relays = [
        (SW // 2 - 140 * SCALE, SH - pad - 60 * SCALE),
        (SW // 2 + 10 * SCALE, SH - pad - 50 * SCALE),
        (SW // 2 + 130 * SCALE, SH - pad - 70 * SCALE)
    ]
    for rx, ry in relays:
        # Antenna tower mast
        draw.line([(rx, ry), (rx, ry - 35 * SCALE)], fill=(180, 180, 190, 240), width=3 * SCALE)
        draw.line([(rx - 8 * SCALE, ry), (rx, ry - 35 * SCALE), (rx + 8 * SCALE, ry)], fill=(140, 140, 150, 180), width=2 * SCALE)
        # Red beacon tip
        draw.ellipse([rx - 4 * SCALE, ry - 39 * SCALE, rx + 4 * SCALE, ry - 31 * SCALE], fill=(255, 30, 40, 255))
        # Concentric jamming radio wave arcs
        for rad in [14 * SCALE, 26 * SCALE, 38 * SCALE]:
            draw.arc([rx - rad, ry - 35 * SCALE - rad, rx + rad, ry - 35 * SCALE + rad], start=210, end=330, fill=(255, 40, 60, 180), width=2 * SCALE)
            
    # Flight path vector line winding between cliffs
    draw.line([(SW // 2 - 60 * SCALE, SH - pad - 35 * SCALE), (SW // 2 - 20 * SCALE, SH - pad - 42 * SCALE),
               (SW // 2 + 50 * SCALE, SH - pad - 38 * SCALE), (SW // 2 + 80 * SCALE, SH - pad - 45 * SCALE)],
              fill=(0, 255, 200, 220), width=2 * SCALE)
    
    f_info = get_font(9)
    draw.text((pad + 18 * SCALE, SH - pad - 26 * SCALE), "OBJ: DESTROY 3 JAMMING RELAYS // NEUTRALIZE CANYON ESCORTS // TERRAIN MASKING REQ",
              fill=(255, 140, 50, 220), font=f_info)
    
    return img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

def create_card_m03():
    img = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = 20 * SCALE
    
    draw_hud_frame(draw, "OPERATION: APEX LIFTOFF [M-03]", "THEATER: EQUATORIAL CATAPULT CORRIDOR // ESCORT PROTOCOL", (0, 255, 170, 240))
    
    # Perspective Magnetic Catapult Launch Rail (Glowing blue rails converging to horizon)
    horizon_y = SH // 2 - 20 * SCALE
    rx_mid = SW // 2
    draw.line([(pad + 50 * SCALE, SH - pad), (rx_mid - 20 * SCALE, horizon_y)], fill=(0, 200, 255, 230), width=3 * SCALE)
    draw.line([(SW - pad - 50 * SCALE, SH - pad), (rx_mid + 20 * SCALE, horizon_y)], fill=(0, 200, 255, 230), width=3 * SCALE)
    # Rail magnetic ties
    for i in range(12):
        t = (i + 1) / 13.0
        y = (SH - pad) * (1 - t) + horizon_y * t
        w = ((SW - pad - 50 * SCALE) - (pad + 50 * SCALE)) * (1 - t) + 40 * SCALE * t
        lx = rx_mid - w / 2
        rx = rx_mid + w / 2
        draw.line([(lx, y), (rx, y)], fill=(0, 180, 240, int(180 * (1 - t * 0.5))), width=2 * SCALE)
    
    # Heavy Transport Olympus-4 Silhouette (Central ascending ship)
    tx, ty = SW // 2, SH // 2 + 10 * SCALE
    # Hull
    draw.polygon([(tx, ty - 35 * SCALE), (tx + 30 * SCALE, ty - 5 * SCALE), (tx + 22 * SCALE, ty + 25 * SCALE),
                  (tx - 22 * SCALE, ty + 25 * SCALE), (tx - 30 * SCALE, ty - 5 * SCALE)],
                 fill=(28, 48, 70, 240), outline=(0, 230, 255, 220), width=2 * SCALE)
    # Cargo wings
    draw.polygon([(tx - 22 * SCALE, ty + 10 * SCALE), (tx - 55 * SCALE, ty + 20 * SCALE), (tx - 22 * SCALE, ty + 25 * SCALE)],
                 fill=(20, 38, 56, 240), outline=(0, 230, 255, 180), width=1 * SCALE)
    draw.polygon([(tx + 22 * SCALE, ty + 10 * SCALE), (tx + 55 * SCALE, ty + 20 * SCALE), (tx + 22 * SCALE, ty + 25 * SCALE)],
                 fill=(20, 38, 56, 240), outline=(0, 230, 255, 180), width=1 * SCALE)
    # Twin rocket plumes
    for ex in [tx - 12 * SCALE, tx + 12 * SCALE]:
        draw.polygon([(ex - 4 * SCALE, ty + 26 * SCALE), (ex + 4 * SCALE, ty + 26 * SCALE), (ex, ty + 55 * SCALE)],
                     fill=(255, 160, 40, 230))
        draw.polygon([(ex - 2 * SCALE, ty + 26 * SCALE), (ex + 2 * SCALE, ty + 26 * SCALE), (ex, ty + 42 * SCALE)],
                     fill=(255, 255, 180, 255))
                     
    # Shield bubble arc around Olympus-4
    draw.arc([tx - 65 * SCALE, ty - 45 * SCALE, tx + 65 * SCALE, ty + 40 * SCALE], start=160, end=380,
             fill=(0, 255, 240, 140), width=2 * SCALE)
    
    # Escort fighters (Vanguard 1 left, Miller right)
    draw.polygon([(tx - 95 * SCALE, ty - 15 * SCALE), (tx - 85 * SCALE, ty), (tx - 95 * SCALE, ty - 4 * SCALE), (tx - 105 * SCALE, ty)],
                 fill=(0, 255, 180, 240))
    draw.polygon([(tx + 95 * SCALE, ty - 15 * SCALE), (tx + 105 * SCALE, ty), (tx + 95 * SCALE, ty - 4 * SCALE), (tx + 85 * SCALE, ty)],
                 fill=(80, 220, 120, 240))
                 
    # Enemy dive vector lines
    for dx in [tx - 130 * SCALE, tx + 130 * SCALE]:
        draw.line([(dx, pad + 60 * SCALE), (dx + (30 if dx < tx else -30) * SCALE, pad + 110 * SCALE)],
                  fill=(255, 50, 60, 190), width=2 * SCALE)
    
    f_info = get_font(9)
    draw.text((pad + 18 * SCALE, SH - pad - 26 * SCALE), "ESCORT ASSET: OLYMPUS-4 (CARGO) // FORMATION: CLOSE AIR SUPPORT // THREAT: SATURATION DIVE",
              fill=(0, 255, 170, 220), font=f_info)
    
    return img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

def create_card_m04():
    img = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = 20 * SCALE
    
    draw_hud_frame(draw, "OPERATION: STRATOSPHERE ZERO [M-04]", "THEATER: MESOSPHERE / KARMAN BOUNDARY (48,000M) // ZERO-G", (255, 30, 60, 240))
    
    # Space Zenith background: Earth's glowing horizon curve below
    # Curved planetary surface
    earth_center = (SW // 2, SH + 280 * SCALE)
    earth_radius = 380 * SCALE
    draw.ellipse([earth_center[0] - earth_radius, earth_center[1] - earth_radius,
                  earth_center[0] + earth_radius, earth_center[1] + earth_radius],
                 fill=(8, 22, 42, 255), outline=(0, 200, 255, 180), width=3 * SCALE)
    # Atmospheric glowing cyan limb
    draw.arc([earth_center[0] - earth_radius - 6 * SCALE, earth_center[1] - earth_radius - 6 * SCALE,
              earth_center[0] + earth_radius + 6 * SCALE, earth_center[1] + earth_radius + 6 * SCALE],
             start=200, end=340, fill=(0, 240, 255, 160), width=4 * SCALE)
             
    # Stars in upper void
    stars = [
        (pad + 40 * SCALE, pad + 70 * SCALE), (pad + 120 * SCALE, pad + 90 * SCALE),
        (SW - pad - 60 * SCALE, pad + 80 * SCALE), (SW - pad - 140 * SCALE, pad + 65 * SCALE),
        (SW // 2 - 180 * SCALE, pad + 110 * SCALE), (SW // 2 + 190 * SCALE, pad + 115 * SCALE)
    ]
    for sx, sy in stars:
        draw.ellipse([sx - 1 * SCALE, sy - 1 * SCALE, sx + 1 * SCALE, sy + 1 * SCALE], fill=(255, 255, 255, 200))
        
    # Helion Ace "Combine Ghost" (Crimson Viper silhouette in targeting reticle)
    bx, by = SW // 2, SH // 2 - 15 * SCALE
    # Crimson Boss Silhouette
    draw.polygon([(bx, by - 28 * SCALE), (bx + 26 * SCALE, by + 12 * SCALE), (bx + 18 * SCALE, by + 18 * SCALE),
                  (bx, by + 8 * SCALE), (bx - 18 * SCALE, by + 18 * SCALE), (bx - 26 * SCALE, by + 12 * SCALE)],
                 fill=(180, 15, 30, 240), outline=(255, 40, 60, 255), width=2 * SCALE)
    # Crimson afterburner trail
    draw.polygon([(bx - 5 * SCALE, by + 16 * SCALE), (bx + 5 * SCALE, by + 16 * SCALE), (bx, by + 36 * SCALE)],
                 fill=(255, 60, 80, 220))
                 
    # Precision Sniper Lock Reticle
    reticle_rad = 55 * SCALE
    draw.ellipse([bx - reticle_rad, by - reticle_rad, bx + reticle_rad, by + reticle_rad],
                 outline=(255, 40, 60, 200), width=2 * SCALE)
    draw.line([(bx - reticle_rad - 15 * SCALE, by), (bx - reticle_rad + 10 * SCALE, by)], fill=(255, 50, 70, 240), width=2 * SCALE)
    draw.line([(bx + reticle_rad - 10 * SCALE, by), (bx + reticle_rad + 15 * SCALE, by)], fill=(255, 50, 70, 240), width=2 * SCALE)
    draw.line([(bx, by - reticle_rad - 15 * SCALE), (bx, by - reticle_rad + 10 * SCALE)], fill=(255, 50, 70, 240), width=2 * SCALE)
    draw.line([(bx, by + reticle_rad - 10 * SCALE), (bx, by + reticle_rad + 15 * SCALE)], fill=(255, 50, 70, 240), width=2 * SCALE)
    
    # 4 Elite Guard Diamond Escorts surrounding boss
    guards = [
        (bx - 70 * SCALE, by - 25 * SCALE),
        (bx + 70 * SCALE, by - 25 * SCALE),
        (bx - 90 * SCALE, by + 20 * SCALE),
        (bx + 90 * SCALE, by + 20 * SCALE)
    ]
    for gx, gy in guards:
        gs = 6 * SCALE
        draw.polygon([(gx, gy - gs), (gx + gs, gy), (gx, gy + gs), (gx - gs, gy)], fill=(255, 90, 100, 220))
        
    f_info = get_font(9)
    draw.text((pad + 18 * SCALE, SH - pad - 26 * SCALE), "TARGET: COMBINE GHOST (ACE) // AIRFRAME: CRIMSON F-82 // STALL SPEED: 45 M/S // 6-DOF RCS",
              fill=(255, 80, 100, 220), font=f_info)
    
    return img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

def create_card_m05():
    img = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = 20 * SCALE
    
    draw_hud_frame(draw, "OPERATION: SILENT ORBIT [M-05]", "THEATER: GORDIAN BELT RIM // PROXIMITY SCREEN // ZERO-G", (255, 180, 0, 240))
    
    # Asteroid field silhouettes
    asteroids = [
        (SW // 2 - 140 * SCALE, SH // 2 + 10 * SCALE, 45 * SCALE),
        (SW // 2 + 160 * SCALE, SH // 2 - 30 * SCALE, 55 * SCALE),
        (SW // 2 - 40 * SCALE, SH // 2 - 60 * SCALE, 30 * SCALE),
        (SW // 2 + 80 * SCALE, SH // 2 + 70 * SCALE, 38 * SCALE)
    ]
    for ax, ay, ar in asteroids:
        draw.ellipse([ax - ar, ay - ar, ax + ar, ay + ar], fill=(22, 24, 28, 200), outline=(60, 65, 75, 220), width=2 * SCALE)
    
    # 4 Amber Tether Mines
    mines = [
        (SW // 2 - 90 * SCALE, SH // 2 + 30 * SCALE),
        (SW // 2 + 70 * SCALE, SH // 2 - 20 * SCALE),
        (SW // 2 - 20 * SCALE, SH // 2 + 60 * SCALE),
        (SW // 2 + 110 * SCALE, SH // 2 + 40 * SCALE)
    ]
    for mx, my in mines:
        # Warning diamond & tether radius
        draw.ellipse([mx - 22*SCALE, my - 22*SCALE, mx + 22*SCALE, my + 22*SCALE], outline=(255, 160, 0, 80), width=1*SCALE)
        ms = 7 * SCALE
        draw.polygon([(mx, my - ms), (mx + ms, my), (mx, my + ms), (mx - ms, my)], fill=(255, 170, 0, 240))
        # Spikes
        draw.line([(mx - 12*SCALE, my), (mx + 12*SCALE, my)], fill=(255, 190, 0, 240), width=2*SCALE)
        draw.line([(mx, my - 12*SCALE), (mx, my + 12*SCALE)], fill=(255, 190, 0, 240), width=2*SCALE)

    f_info = get_font(9)
    draw.text((pad + 18 * SCALE, SH - pad - 26 * SCALE), "THREAT: 4X TETHER-MINE CLUSTERS // 4X CLOAKED SKIRMISHERS // VACUUM PHYSICS (STALL: 0 M/S)",
              fill=(255, 180, 0, 230), font=f_info)
    return img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

def create_card_m06():
    img = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = 20 * SCALE
    
    draw_hud_frame(draw, "OPERATION: GHOST REEF [M-06]", "THEATER: ASTEROID 433-EROS // THE IRON HOLLOW // CLEARANCE: 140M", (0, 240, 255, 240))
    
    # Wireframe Cavern Tunnel Rings
    cx, cy = SW // 2, SH // 2 + 15 * SCALE
    for rad, alpha in [(120 * SCALE, 60), (95 * SCALE, 100), (70 * SCALE, 140), (45 * SCALE, 200)]:
        draw.ellipse([cx - rad, cy - rad * 0.7, cx + rad, cy + rad * 0.7], outline=(0, 200, 255, alpha), width=2 * SCALE)
    
    # Laser Cutter Grids (Red warning beams across tunnel)
    draw.line([(cx - 80 * SCALE, cy - 30 * SCALE), (cx + 80 * SCALE, cy + 30 * SCALE)], fill=(255, 30, 60, 220), width=2 * SCALE)
    draw.line([(cx - 70 * SCALE, cy + 35 * SCALE), (cx + 70 * SCALE, cy - 35 * SCALE)], fill=(255, 30, 60, 220), width=2 * SCALE)
    
    # 3 Geothermal Extraction Generators (Cyan Cores)
    gens = [
        (cx - 75 * SCALE, cy + 10 * SCALE),
        (cx + 80 * SCALE, cy - 10 * SCALE),
        (cx, cy + 45 * SCALE)
    ]
    for gx, gy in gens:
        draw.rectangle([gx - 10*SCALE, gy - 10*SCALE, gx + 10*SCALE, gy + 10*SCALE], fill=(0, 240, 255, 240), outline=(255, 255, 255, 255), width=2*SCALE)
        
    f_info = get_font(9)
    draw.text((pad + 18 * SCALE, SH - pad - 26 * SCALE), "OBJECTIVES: 3X GEOTHERMAL CORES // 6X WALL SENTRIES // ESCAPE SHAFT BEFORE MELTDOWN",
              fill=(0, 240, 255, 230), font=f_info)
    return img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

def create_card_m07():
    img = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = 20 * SCALE
    
    draw_hud_frame(draw, "OPERATION: DAUNTLESS DEFENDER [M-07]", "THEATER: 5TH FLEET PERIMETER // CARRIER ESCORT // TORPEDO THREAT", (100, 220, 255, 240))
    
    # Carrier SOC Dauntless Silhouette (Center Left)
    cx, cy = SW // 2 - 60 * SCALE, SH // 2 + 10 * SCALE
    draw.polygon([
        (cx - 130 * SCALE, cy - 25 * SCALE),
        (cx + 120 * SCALE, cy - 30 * SCALE),
        (cx + 140 * SCALE, cy + 20 * SCALE),
        (cx - 110 * SCALE, cy + 25 * SCALE)
    ], fill=(20, 35, 55, 240), outline=(0, 180, 255, 220), width=2 * SCALE)
    # Island tower
    draw.rectangle([cx + 30 * SCALE, cy - 50 * SCALE, cx + 60 * SCALE, cy - 25 * SCALE], fill=(30, 50, 75, 240), outline=(255, 200, 0, 240), width=2 * SCALE)
    
    # 3 Incoming Fusion Torpedo Vectors (Red arrows plunging toward carrier)
    torps = [
        ((SW // 2 + 140 * SCALE, cy - 80 * SCALE), (cx + 80 * SCALE, cy - 20 * SCALE)),
        ((SW // 2 + 160 * SCALE, cy + 10 * SCALE), (cx + 90 * SCALE, cy + 5 * SCALE)),
        ((SW // 2 + 130 * SCALE, cy + 90 * SCALE), (cx + 70 * SCALE, cy + 20 * SCALE))
    ]
    for start, end in torps:
        draw.line([start, end], fill=(255, 50, 50, 220), width=3 * SCALE)
        tx, ty = start
        draw.ellipse([tx - 8*SCALE, ty - 8*SCALE, tx + 8*SCALE, ty + 8*SCALE], fill=(255, 60, 60, 255))
        
    f_info = get_font(9)
    draw.text((pad + 18 * SCALE, SH - pad - 26 * SCALE), "PROTECTED ASSET: SOC DAUNTLESS (1,000 HP) // INTERCEPT 8X HEAVY FUSION TORPEDOES",
              fill=(255, 100, 100, 230), font=f_info)
    return img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

def create_card_m08():
    img = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = 20 * SCALE
    
    draw_hud_frame(draw, "OPERATION: NEXUS CRUCIBLE [M-08]", "THEATER: CELESTIAL FORGE // DREADNOUGHT NEMESIS-9 // CHAPTER 2 CLIMAX", (255, 60, 80, 240), border_color=(255, 50, 70, 200))
    
    # Dreadnought Nemesis-9 Menacing Dagger Silhouette
    cx, cy = SW // 2, SH // 2 + 5 * SCALE
    draw.polygon([
        (cx + 140 * SCALE, cy),
        (cx - 110 * SCALE, cy - 65 * SCALE),
        (cx - 140 * SCALE, cy - 35 * SCALE),
        (cx - 140 * SCALE, cy + 35 * SCALE),
        (cx - 110 * SCALE, cy + 65 * SCALE)
    ], fill=(25, 18, 22, 240), outline=(255, 40, 60, 240), width=2 * SCALE)
    
    # Railgun Prow
    draw.rectangle([cx + 100 * SCALE, cy - 8 * SCALE, cx + 160 * SCALE, cy + 8 * SCALE], fill=(40, 20, 25, 240), outline=(255, 70, 90, 240), width=2 * SCALE)
    
    # 4 Rotary Flak Pods (Subsystem targets)
    flak_pods = [
        (cx - 20 * SCALE, cy - 40 * SCALE),
        (cx + 40 * SCALE, cy - 30 * SCALE),
        (cx - 20 * SCALE, cy + 40 * SCALE),
        (cx + 40 * SCALE, cy + 30 * SCALE)
    ]
    for fx, fy in flak_pods:
        draw.ellipse([fx - 8*SCALE, fy - 8*SCALE, fx + 8*SCALE, fy + 8*SCALE], outline=(255, 180, 0, 240), width=2*SCALE)
        
    # Central Reactor Core
    draw.ellipse([cx - 50*SCALE, cy - 14*SCALE, cx - 18*SCALE, cy + 14*SCALE], fill=(255, 30, 40, 240), outline=(255, 255, 255, 255), width=2*SCALE)
    
    f_info = get_font(9)
    draw.text((pad + 18 * SCALE, SH - pad - 26 * SCALE), "BOSS: NEMESIS-9 (WARLORD VANE) // PHASE 1: FLAK PODS // PHASE 2: SHIELDS // PHASE 3: REACTOR",
              fill=(255, 80, 100, 240), font=f_info)
    return img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

def main():
    generators = [
        ("mission_card_m01.png", create_card_m01),
        ("mission_card_m02.png", create_card_m02),
        ("mission_card_m03.png", create_card_m03),
        ("mission_card_m04.png", create_card_m04),
        ("mission_card_m05.png", create_card_m05),
        ("mission_card_m06.png", create_card_m06),
        ("mission_card_m07.png", create_card_m07),
        ("mission_card_m08.png", create_card_m08)
    ]
    
    for filename, gen_func in generators:
        card_img = gen_func()
        for out_dir in OUT_DIRS:
            os.makedirs(out_dir, exist_ok=True)
            out_path = os.path.join(out_dir, filename)
            card_img.save(out_path, "PNG")
            print(f"Generated {filename} -> {out_path} ({card_img.size})")

if __name__ == "__main__":
    main()
