extends Control

var ship: CharacterBody3D
var telemetry: Node
var camera: Camera3D

# Visual Configuration (Cyan & Gold Military Sci-Fi Theme)
const COLOR_CYAN = Color(0.0, 0.90, 1.0, 0.92)
const COLOR_CYAN_DIM = Color(0.0, 0.70, 0.85, 0.40)
const COLOR_GOLD = Color(1.0, 0.84, 0.0, 0.95)
const COLOR_RED = Color(1.0, 0.16, 0.28, 0.95)
const COLOR_GREEN = Color(0.1, 0.95, 0.4, 0.9)
const COLOR_PANEL_BG = Color(0.04, 0.07, 0.11, 0.65)
const COLOR_SHIELD = Color(0.2, 0.75, 1.0, 0.9)

# Radar Toggle
var show_circular_radar: bool = true

func _ready() -> void:
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg:
		show_circular_radar = cfg.radar_circular_default
		cfg.settings_changed.connect(func(): show_circular_radar = cfg.radar_circular_default)
	var root = get_tree().current_scene
	if root:
		ship = root.get_node_or_null("Spaceship") as CharacterBody3D
		camera = root.get_node_or_null("Camera3D") as Camera3D
	if ship:
		telemetry = ship.get_node_or_null("CombatTelemetry")

func _unhandled_input(event: InputEvent) -> void:
	# Toggle circular radar via customizable action
	if event.is_action_pressed("toggle_radar"):
		show_circular_radar = not show_circular_radar
		queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not ship or not camera or not telemetry:
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var center = viewport_size * 0.5

	# 1. Top Compass Horizon Ribbon
	_draw_compass_ribbon(viewport_size)

	# 2. Circular Tactical Radar Disc (Upper Right)
	if show_circular_radar:
		_draw_circular_radar(viewport_size)

	# 3. Center Crosshair & Pitch Reticle
	_draw_center_crosshair(center)

	# 4. Target Acquisition & Missile Lock-On Reticle
	_draw_target_tracking(viewport_size, center)

	# 5. Left Panel: Speed, Altitude & Vital Systems (Shield / Hull)
	_draw_vital_systems(viewport_size)

	# 6. Right Panel: Nitro Capacitor & Ordnance Bays
	_draw_nitro_and_ordnance(viewport_size)

	# 7. Stall Warning (Center Screen)
	if ship.enable_gravity and ship.current_speed < ship.stall_speed:
		_draw_stall_warning(center)

# -----------------------------------------------------------------
# 1. Top Compass Horizon Ribbon
# -----------------------------------------------------------------
func _draw_compass_ribbon(vp: Vector2) -> void:
	var width = 460.0
	var height = 38.0
	var rect = Rect2(Vector2((vp.x - width) * 0.5, 14.0), Vector2(width, height))
	
	# Background
	draw_rect(rect, COLOR_PANEL_BG, true)
	draw_rect(rect, COLOR_CYAN_DIM, false, 1.5)
	
	# Center pointer tick (inverted triangle)
	var cx = vp.x * 0.5
	var cy = rect.position.y + rect.size.y
	var tri = PackedVector2Array([
		Vector2(cx, cy + 1),
		Vector2(cx - 5, cy - 7),
		Vector2(cx + 5, cy - 7)
	])
	draw_colored_polygon(tri, COLOR_CYAN)

	# Ship Yaw in degrees (0 to 360)
	var forward = -ship.global_transform.basis.z.normalized()
	var yaw_rad = atan2(forward.x, -forward.z)
	var yaw_deg = fposmod(rad_to_deg(yaw_rad), 360.0)

	# Cardinal points
	var cardinals = {
		0: "N", 45: "045", 90: "E", 135: "135",
		180: "S", 225: "225", 270: "W", 315: "315"
	}

	var fov_span = 70.0 # Visible degrees across the ribbon
	var px_per_deg = width / fov_span

	for deg in range(0, 360, 15):
		var diff = deg - yaw_deg
		while diff > 180.0: diff -= 360.0
		while diff < -180.0: diff += 360.0

		if abs(diff) < (fov_span * 0.5):
			var tick_x = cx + (diff * px_per_deg)
			var is_major = (deg % 45 == 0)
			var tick_h = 10.0 if is_major else 5.0
			draw_line(Vector2(tick_x, rect.position.y + 2), Vector2(tick_x, rect.position.y + 2 + tick_h), COLOR_CYAN if is_major else COLOR_CYAN_DIM, 1.0)
			
			if is_major and cardinals.has(deg):
				var label = cardinals[deg]
				var col = COLOR_GOLD if label in ["N", "E", "S", "W"] else COLOR_CYAN
				draw_string(ThemeDB.fallback_font, Vector2(tick_x - 8, rect.position.y + 24), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, col)

	# Plot Radar Targets onto Compass Ribbon
	for t in telemetry.detected_targets:
		var az = t["azimuth_deg"]
		if abs(az) < (fov_span * 0.5):
			var pip_x = cx + (az * px_per_deg)
			var pip_y = rect.position.y + rect.size.y - 12
			var col = COLOR_RED if t["is_hostile"] else COLOR_GOLD
			
			if t["is_hostile"]:
				# Enemy Diamond (RED)
				var diamond = PackedVector2Array([
					Vector2(pip_x, pip_y - 4),
					Vector2(pip_x + 4, pip_y),
					Vector2(pip_x, pip_y + 4),
					Vector2(pip_x - 4, pip_y)
				])
				draw_colored_polygon(diamond, col)
			else:
				# Objective Circle (GOLD)
				draw_circle(Vector2(pip_x, pip_y), 3.5, col)

# -----------------------------------------------------------------
# 2. Circular Tactical Radar Disc (Upper Right)
# -----------------------------------------------------------------
func _draw_circular_radar(vp: Vector2) -> void:
	var radius = 70.0
	var radar_center = Vector2(vp.x - radius - 24, radius + 24)
	
	# Background disc
	draw_circle(radar_center, radius, COLOR_PANEL_BG)
	draw_arc(radar_center, radius, 0, TAU, 48, COLOR_CYAN_DIM, 1.5)
	draw_arc(radar_center, radius * 0.66, 0, TAU, 32, COLOR_CYAN_DIM * 0.6, 1.0)
	draw_arc(radar_center, radius * 0.33, 0, TAU, 24, COLOR_CYAN_DIM * 0.6, 1.0)

	# Crosshairs
	draw_line(Vector2(radar_center.x - radius, radar_center.y), Vector2(radar_center.x + radius, radar_center.y), COLOR_CYAN_DIM * 0.5, 1.0)
	draw_line(Vector2(radar_center.x, radar_center.y - radius), Vector2(radar_center.x, radar_center.y + radius), COLOR_CYAN_DIM * 0.5, 1.0)

	# Forward Vision Cone (60 deg)
	var cone_angle = deg_to_rad(30.0)
	var left_pt = radar_center + Vector2(sin(-cone_angle), -cos(-cone_angle)) * radius
	var right_pt = radar_center + Vector2(sin(cone_angle), -cos(cone_angle)) * radius
	draw_line(radar_center, left_pt, COLOR_CYAN * 0.4, 1.0)
	draw_line(radar_center, right_pt, COLOR_CYAN * 0.4, 1.0)

	# Player center pip
	draw_circle(radar_center, 2.5, COLOR_CYAN)

	# Plot targets on radar disc
	var max_range = telemetry.max_radar_range_m
	for t in telemetry.detected_targets:
		var dist_ratio = clamp(t["distance"] / max_range, 0.0, 1.0)
		var az_rad = deg_to_rad(t["azimuth_deg"])
		# 0 deg azimuth is straight up (-Y in 2D canvas)
		var target_offset = Vector2(sin(az_rad), -cos(az_rad)) * (dist_ratio * radius)
		var pip_pos = radar_center + target_offset
		var col = COLOR_RED if t["is_hostile"] else COLOR_GOLD
		draw_circle(pip_pos, 3.5, col)
		if t["is_hostile"]:
			draw_arc(pip_pos, 5.0, 0, TAU, 12, COLOR_RED * 0.6, 1.0)

	# Header label
	draw_string(ThemeDB.fallback_font, Vector2(radar_center.x - 45, radar_center.y + radius + 16), "RADAR [R: TOGGLE]", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, COLOR_CYAN_DIM)

# -----------------------------------------------------------------
# 3. Center Crosshair Reticle
# -----------------------------------------------------------------
func _draw_center_crosshair(center: Vector2) -> void:
	var r = 16.0
	draw_arc(center, r, 0, TAU, 32, COLOR_CYAN_DIM, 1.5)
	draw_circle(center, 2.0, COLOR_CYAN)
	
	# Horizontal flight level brackets
	draw_line(Vector2(center.x - 36, center.y), Vector2(center.x - 22, center.y), COLOR_CYAN, 2.0)
	draw_line(Vector2(center.x + 22, center.y), Vector2(center.x + 36, center.y), COLOR_CYAN, 2.0)
	draw_line(Vector2(center.x - 36, center.y), Vector2(center.x - 36, center.y + 6), COLOR_CYAN, 2.0)
	draw_line(Vector2(center.x + 36, center.y), Vector2(center.x + 36, center.y + 6), COLOR_CYAN, 2.0)

# -----------------------------------------------------------------
# 4. Target Acquisition & Missile Lock-On Reticle
# -----------------------------------------------------------------
func _draw_target_tracking(vp: Vector2, center: Vector2) -> void:
	for t in telemetry.detected_targets:
		var w_pos = t["world_pos"]
		var is_behind = camera.is_position_behind(w_pos)
		var s_pos = camera.unproject_position(w_pos)
		
		if not is_behind and Rect2(Vector2.ZERO, vp).has_point(s_pos):
			# Target in viewport view
			var dist_m = round(t["distance"])
			var is_current_locked_candidate = (t["node"] == telemetry.current_target)
			var box_col = COLOR_RED if t["is_hostile"] else COLOR_GOLD
			
			# Target Corner Brackets
			var b_size = clamp(3600.0 / max(dist_m, 10.0), 22.0, 64.0)
			_draw_bracket_box(s_pos, b_size, box_col)
			
			# Range label
			var info_txt = "%s [%dm]" % [t["name"], dist_m]
			draw_string(ThemeDB.fallback_font, Vector2(s_pos.x - 40, s_pos.y + b_size + 14), info_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, box_col)
			
			# Missile Lock Reticle
			if is_current_locked_candidate and telemetry.lock_progress > 0.0:
				var ring_r = b_size * 1.4
				if telemetry.is_locked:
					# SOLID LOCKED STATE
					draw_arc(s_pos, ring_r, 0, TAU, 36, COLOR_RED, 3.0)
					draw_string(ThemeDB.fallback_font, Vector2(s_pos.x - 55, s_pos.y - ring_r - 8), ">>> LOCKED <<<", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, COLOR_RED)
				else:
					# LOCK ACQUIRING PROGRESS RING
					var sweep = telemetry.lock_progress * TAU
					draw_arc(s_pos, ring_r, -PI*0.5, -PI*0.5 + sweep, 28, COLOR_GOLD, 2.5)
					draw_string(ThemeDB.fallback_font, Vector2(s_pos.x - 40, s_pos.y - ring_r - 8), "ACQUIRING...", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, COLOR_GOLD)
		else:
			# Target Off-Screen: Draw edge chevron indicator
			var screen_center = vp * 0.5
			var dir_2d = (s_pos - screen_center).normalized()
			if is_behind:
				dir_2d = -dir_2d # Invert for behind camera
			var edge_pos = screen_center + dir_2d * (min(vp.x, vp.y) * 0.44)
			var arrow_col = COLOR_RED if t["is_hostile"] else COLOR_GOLD
			draw_circle(edge_pos, 5.0, arrow_col)

func _draw_bracket_box(pos: Vector2, size: float, col: Color) -> void:
	var h = size * 0.5
	var arm = size * 0.3
	# Top-Left
	draw_line(Vector2(pos.x - h, pos.y - h), Vector2(pos.x - h + arm, pos.y - h), col, 2.0)
	draw_line(Vector2(pos.x - h, pos.y - h), Vector2(pos.x - h, pos.y - h + arm), col, 2.0)
	# Top-Right
	draw_line(Vector2(pos.x + h, pos.y - h), Vector2(pos.x + h - arm, pos.y - h), col, 2.0)
	draw_line(Vector2(pos.x + h, pos.y - h), Vector2(pos.x + h, pos.y - h + arm), col, 2.0)
	# Bottom-Left
	draw_line(Vector2(pos.x - h, pos.y + h), Vector2(pos.x - h + arm, pos.y + h), col, 2.0)
	draw_line(Vector2(pos.x - h, pos.y + h), Vector2(pos.x - h, pos.y + h - arm), col, 2.0)
	# Bottom-Right
	draw_line(Vector2(pos.x + h, pos.y + h), Vector2(pos.x + h - arm, pos.y + h), col, 2.0)
	draw_line(Vector2(pos.x + h, pos.y + h), Vector2(pos.x + h, pos.y + h - arm), col, 2.0)

# -----------------------------------------------------------------
# 5. Left Panel: Vital Systems (Shield, Hull, Speed, Altitude)
# -----------------------------------------------------------------
func _draw_vital_systems(vp: Vector2) -> void:
	var px = 24.0
	var py = vp.y - 190.0
	var panel_w = 260.0
	var panel_h = 166.0

	draw_rect(Rect2(Vector2(px, py), Vector2(panel_w, panel_h)), COLOR_PANEL_BG, true)
	draw_rect(Rect2(Vector2(px, py), Vector2(panel_w, panel_h)), COLOR_CYAN_DIM, false, 1.5)

	# Header
	var layout_txt = "AZERTY (Belgian)" if ship.is_azerty else "QWERTY (Standard)"
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 20), "SYSTEM INTEGRITY | " + layout_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_CYAN)

	# Deflector Shield Bar
	var s_pct = telemetry.current_shield / telemetry.max_shield
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 42), "SHIELD %d%%" % round(s_pct * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_SHIELD)
	draw_rect(Rect2(Vector2(px + 12, py + 48), Vector2(panel_w - 24, 10)), COLOR_CYAN_DIM * 0.4, true)
	draw_rect(Rect2(Vector2(px + 12, py + 48), Vector2((panel_w - 24) * s_pct, 10)), COLOR_SHIELD, true)

	# Hull Armor Bar
	var h_pct = telemetry.current_hull / telemetry.max_hull
	var hull_col = COLOR_GREEN if h_pct > 0.65 else (COLOR_GOLD if h_pct > 0.3 else COLOR_RED)
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 76), "HULL ARMOR %d%%" % round(h_pct * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, hull_col)
	draw_rect(Rect2(Vector2(px + 12, py + 82), Vector2(panel_w - 24, 10)), COLOR_CYAN_DIM * 0.4, true)
	draw_rect(Rect2(Vector2(px + 12, py + 82), Vector2((panel_w - 24) * h_pct, 10)), hull_col, true)

	# Speed & Altitude
	var speed_kmh = round(ship.current_speed * 3.6)
	var alt_m = round(ship.global_position.y)
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 115), "AIRSPEED:  %d km/h" % speed_kmh, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_CYAN)
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 135), "ALTITUDE:  %d m" % alt_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_CYAN)
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 155), "[F1: Layout | H: Test Damage]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_CYAN_DIM)

# -----------------------------------------------------------------
# 6. Right Panel: Nitro & Ordnance Bays
# -----------------------------------------------------------------
func _draw_nitro_and_ordnance(vp: Vector2) -> void:
	var panel_w = 260.0
	var panel_h = 166.0
	var px = vp.x - panel_w - 24.0
	var py = vp.y - 190.0

	draw_rect(Rect2(Vector2(px, py), Vector2(panel_w, panel_h)), COLOR_PANEL_BG, true)
	draw_rect(Rect2(Vector2(px, py), Vector2(panel_w, panel_h)), COLOR_CYAN_DIM, false, 1.5)

	# Header
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 20), "ORDNANCE & AFTERBURNER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_CYAN)

	# Nitro / Afterburner Bar
	var n_pct = telemetry.current_nitro / telemetry.max_nitro
	var nitro_col = COLOR_RED if telemetry.is_overheated else (COLOR_GOLD if Input.is_key_pressed(KEY_SHIFT) else COLOR_CYAN)
	var nitro_label = "OVERHEAT LOCKOUT" if telemetry.is_overheated else ("AFTERBURNER [BOOST]" if Input.is_key_pressed(KEY_SHIFT) else "NITRO CAPACITOR %d%%" % round(n_pct * 100))

	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 42), nitro_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, nitro_col)
	draw_rect(Rect2(Vector2(px + 12, py + 48), Vector2(panel_w - 24, 10)), COLOR_CYAN_DIM * 0.4, true)
	draw_rect(Rect2(Vector2(px + 12, py + 48), Vector2((panel_w - 24) * n_pct, 10)), nitro_col, true)

	# Missile Hardpoint Pylons (4x Bays)
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 78), "VANGUARD STRIKE MISSILES: %d / %d" % [telemetry.missiles_remaining, telemetry.max_missiles], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GOLD)
	
	var bay_w = 48.0
	var bay_h = 24.0
	var bay_gap = 12.0
	var start_x = px + 12.0
	var bay_y = py + 88.0

	for i in range(telemetry.max_missiles):
		var bx = start_x + (i * (bay_w + bay_gap))
		var is_loaded = (i < telemetry.missiles_remaining)
		var b_col = COLOR_GOLD if is_loaded else COLOR_CYAN_DIM * 0.4
		
		draw_rect(Rect2(Vector2(bx, bay_y), Vector2(bay_w, bay_h)), COLOR_PANEL_BG, true)
		draw_rect(Rect2(Vector2(bx, bay_y), Vector2(bay_w, bay_h)), b_col, false, 1.5)
		
		var m_label = "HP 0%d" % (i + 1)
		draw_string(ThemeDB.fallback_font, Vector2(bx + 6, bay_y + 16), m_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, b_col)

	# Weapon Trigger Guide
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 135), "CANNON: 20mm GAU-22 [READY]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_CYAN)
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 155), "[SPACE: Fire Missile | SHIFT: Boost]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_CYAN_DIM)

# -----------------------------------------------------------------
# 7. Stall Warning Banner
# -----------------------------------------------------------------
func _draw_stall_warning(center: Vector2) -> void:
	var banner_w = 320.0
	var banner_h = 36.0
	var bx = center.x - (banner_w * 0.5)
	var by = center.y + 110.0

	draw_rect(Rect2(Vector2(bx, by), Vector2(banner_w, banner_h)), Color(0.2, 0.02, 0.04, 0.85), true)
	draw_rect(Rect2(Vector2(bx, by), Vector2(banner_w, banner_h)), COLOR_RED, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(bx + 20, by + 23), ">>> STALL WARNING - INSUFFICIENT LIFT <<<", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, COLOR_RED)
