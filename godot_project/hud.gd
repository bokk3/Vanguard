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

# Hitmarker & Combat Feedback
var hitmarker_timer: float = 0.0
var combat_event_text: String = ""
var combat_event_color: Color = COLOR_CYAN
var combat_event_timer: float = 0.0

# Radio Comms & Mission Objectives
var current_radio_speaker: String = ""
var current_radio_callsign: String = ""
var current_radio_text: String = ""
var current_radio_color: Color = Color.WHITE
var current_radio_timer: float = 0.0
var radio_banner_active: bool = false
var mission_title: String = ""
var mission_objectives: Array[Dictionary] = []

# Flight Telemetry & G-Force Avionics
var current_g_force: float = 1.0
var previous_speed: float = 0.0
var high_g_audio_player: AudioStreamPlayer = null
var high_g_cooldown: float = 0.0

func _ready() -> void:
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg:
		show_circular_radar = cfg.radar_circular_default
		cfg.settings_changed.connect(func(): show_circular_radar = cfg.radar_circular_default)
	if get_tree() and get_tree().current_scene:
		var root = get_tree().current_scene
		ship = root.get_node_or_null("Spaceship") as CharacterBody3D
		camera = root.get_node_or_null("Camera3D") as Camera3D
	if ship:
		telemetry = ship.get_node_or_null("CombatTelemetry")
	
	# Setup High-G Cockpit Audio
	high_g_audio_player = AudioStreamPlayer.new()
	high_g_audio_player.name = "HighGAudioPlayer"
	high_g_audio_player.bus = "Master"
	var g_stream = load("res://audio/sfx/sfx_flight_high_g_whoosh.wav")
	if g_stream:
		high_g_audio_player.stream = g_stream
	add_child(high_g_audio_player)
	
	# Connect to MissionManager
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		mm.radio_transmission_started.connect(_on_radio_started)
		mm.radio_transmission_ended.connect(_on_radio_ended)
		mm.objective_updated.connect(_on_objective_updated)
		mm.mission_started.connect(_on_mission_started)
		
		var cur_m = mm.get_mission(mm.current_mission_id)
		if not cur_m.is_empty():
			mission_title = cur_m.get("codename", "")
			mission_objectives = mm.active_objectives.duplicate()

func trigger_hitmarker() -> void:
	hitmarker_timer = 0.35
	queue_redraw()

func notify_combat_event(text: String, col: Color = COLOR_CYAN) -> void:
	combat_event_text = text
	combat_event_color = col
	combat_event_timer = 2.5
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	# Toggle circular radar via customizable action
	if event.is_action_pressed("toggle_radar"):
		show_circular_radar = not show_circular_radar
		queue_redraw()

func _process(delta: float) -> void:
	if hitmarker_timer > 0.0:
		hitmarker_timer = max(0.0, hitmarker_timer - delta)
	if combat_event_timer > 0.0:
		combat_event_timer = max(0.0, combat_event_timer - delta)
	if current_radio_timer > 0.0:
		current_radio_timer = max(0.0, current_radio_timer - delta)
		if current_radio_timer <= 0.0:
			radio_banner_active = false
	
	# Dynamic Aerospace G-Force Calculation & High-G Woosh SFX
	if ship:
		var speed = ship.current_speed
		var accel = (speed - previous_speed) / max(0.001, delta)
		previous_speed = speed
		
		# Centripetal turn rate G load
		var angular_rate = 0.0
		if "mouse_input" in ship and ship.mouse_input != null:
			angular_rate = (ship.mouse_input as Vector2).length() * 32.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S):
			angular_rate = max(angular_rate, 45.0)
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D):
			angular_rate = max(angular_rate, 35.0)
		
		var centripetal_g = (angular_rate * speed) / 120.0
		var linear_g = accel / 35.0
		var target_g = clamp(1.0 + abs(centripetal_g) + abs(linear_g), 1.0, 9.9)
		current_g_force = lerp(current_g_force, target_g, 8.0 * delta)
		
		high_g_cooldown -= delta
		if current_g_force > 6.0 and high_g_cooldown <= 0.0:
			high_g_cooldown = 3.2
			if high_g_audio_player and not high_g_audio_player.playing:
				high_g_audio_player.play()
	
	queue_redraw()

func _on_radio_started(speaker: String, callsign: String, text: String, color: Color, duration: float) -> void:
	current_radio_speaker = speaker
	current_radio_callsign = callsign
	current_radio_text = text
	current_radio_color = color
	current_radio_timer = duration
	radio_banner_active = true
	queue_redraw()

func _on_radio_ended() -> void:
	radio_banner_active = false
	queue_redraw()

func _on_mission_started(mission_id: String, mission_data: Dictionary) -> void:
	mission_title = mission_data.get("codename", mission_id)
	mission_objectives.clear()
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		mission_objectives = mm.active_objectives.duplicate()
	queue_redraw()

func _on_objective_updated(obj_id: String, status: String, text: String, cur_val: Variant, target_val: Variant) -> void:
	var found = false
	for obj in mission_objectives:
		if obj.get("id") == obj_id:
			obj["status"] = status
			obj["text"] = text
			obj["current_val"] = cur_val
			obj["target_val"] = target_val
			found = true
			break
	if not found:
		mission_objectives.append({
			"id": obj_id,
			"status": status,
			"text": text,
			"current_val": cur_val,
			"target_val": target_val
		})
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

	# 3. Center Pitch Ladder, Crosshair & Flight Path Marker
	_draw_pitch_ladder(center)
	_draw_center_crosshair(center)
	_draw_flight_path_marker(viewport_size)

	# 4. Target Acquisition & Missile Lock-On Reticle
	_draw_target_tracking(viewport_size, center)

	# 5. Left Panel: Speed, Altitude & Vital Systems (Shield / Hull)
	_draw_vital_systems(viewport_size)

	# 6. Right Panel: Nitro Capacitor & Ordnance Bays
	_draw_nitro_and_ordnance(viewport_size)

	# 7. Stall Warning (Center Screen)
	if ship.enable_gravity and ship.current_speed < ship.stall_speed:
		_draw_stall_warning(center)

	# 8. Combat Status Event Toast
	_draw_combat_event_toast(center)

	# 9. Tactical Mission Objectives (Left HUD)
	_draw_mission_objectives(viewport_size)

	# 10. Radio Comms Transmission Banner (Top Center)
	if radio_banner_active:
		_draw_radio_comms_banner(viewport_size)

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
# 3. Dynamic Pitch Ladder & Flight Path Marker
# -----------------------------------------------------------------
func _draw_pitch_ladder(center: Vector2) -> void:
	if not ship:
		return
	
	var fwd = -ship.global_transform.basis.z.normalized()
	var right = ship.global_transform.basis.x.normalized()
	var up = ship.global_transform.basis.y.normalized()
	
	var pitch_rad = asin(clamp(fwd.y, -1.0, 1.0))
	var pitch_deg = rad_to_deg(pitch_rad)
	var roll_rad = atan2(right.y, up.y)
	
	var px_per_deg = 4.2
	var ladder_w = 96.0
	var rung_spacing_deg = 10
	
	for p in range(-30, 31, rung_spacing_deg):
		var diff = (pitch_deg - p) * px_per_deg
		if abs(diff) > 135.0:
			continue
		
		var rung_col = COLOR_CYAN_DIM if p != 0 else COLOR_CYAN
		var line_dir = Vector2(cos(roll_rad), sin(roll_rad))
		var perp_dir = Vector2(-sin(roll_rad), cos(roll_rad))
		var rung_center = center + perp_dir * diff
		
		var half_w = ladder_w * 0.5 if p != 0 else ladder_w * 0.85
		var gap = 24.0
		
		var p1_l = rung_center - line_dir * half_w
		var p2_l = rung_center - line_dir * gap
		var p1_r = rung_center + line_dir * gap
		var p2_r = rung_center + line_dir * half_w
		
		if p == 0:
			# Horizon line: long solid bar with center reticle gap
			draw_line(p1_l, p2_l, COLOR_CYAN, 2.0)
			draw_line(p1_r, p2_r, COLOR_CYAN, 2.0)
			draw_line(p1_l, p1_l + perp_dir * 8.0, COLOR_CYAN, 1.5)
			draw_line(p2_r, p2_r + perp_dir * 8.0, COLOR_CYAN, 1.5)
		elif p > 0:
			# Positive pitch: solid lines with downward pointing ends toward horizon
			draw_line(p1_l, p2_l, rung_col, 1.5)
			draw_line(p1_r, p2_r, rung_col, 1.5)
			draw_line(p1_l, p1_l + perp_dir * 6.0, rung_col, 1.5)
			draw_line(p2_r, p2_r + perp_dir * 6.0, rung_col, 1.5)
			var num_pos = p2_r + line_dir * 4.0 - perp_dir * 3.0
			draw_string(ThemeDB.fallback_font, num_pos, str(p), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, rung_col)
		else:
			# Negative pitch: dashed lines with upward pointing ends toward horizon
			_draw_dashed_line_2d(p1_l, p2_l, rung_col, 1.5, 6.0, 4.0)
			_draw_dashed_line_2d(p1_r, p2_r, rung_col, 1.5, 6.0, 4.0)
			draw_line(p1_l, p1_l - perp_dir * 6.0, rung_col, 1.5)
			draw_line(p2_r, p2_r - perp_dir * 6.0, rung_col, 1.5)
			var num_pos = p2_r + line_dir * 4.0 + perp_dir * 5.0
			draw_string(ThemeDB.fallback_font, num_pos, str(p), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, rung_col)

func _draw_flight_path_marker(vp_size: Vector2) -> void:
	if not ship or not camera:
		return
	var speed = ship.velocity.length()
	if speed < 4.0:
		return
	
	var fpm_world = ship.global_position + ship.velocity.normalized() * 50.0
	if camera.is_position_behind(fpm_world):
		return
	var s_pos = camera.unproject_position(fpm_world)
	if not Rect2(Vector2.ZERO, vp_size).has_point(s_pos):
		return
	
	var r = 6.5
	var col = COLOR_GREEN
	draw_arc(s_pos, r, 0, TAU, 24, col, 1.5)
	# Left stabilizer wing
	draw_line(s_pos - Vector2(r + 9.0, 0), s_pos - Vector2(r, 0), col, 1.5)
	# Right stabilizer wing
	draw_line(s_pos + Vector2(r, 0), s_pos + Vector2(r + 9.0, 0), col, 1.5)
	# Vertical rudder fin
	draw_line(s_pos - Vector2(0, r), s_pos - Vector2(0, r + 6.0), col, 1.5)

func _draw_dashed_line_2d(p1: Vector2, p2: Vector2, col: Color, width: float, dash_len: float, gap_len: float) -> void:
	var total_dist = p1.distance_to(p2)
	if total_dist <= 0.001:
		return
	var dir = (p2 - p1).normalized()
	var cur_dist = 0.0
	while cur_dist < total_dist:
		var d_end = min(cur_dist + dash_len, total_dist)
		draw_line(p1 + dir * cur_dist, p1 + dir * d_end, col, width)
		cur_dist += dash_len + gap_len

# -----------------------------------------------------------------
# 3b. Center Crosshair Reticle
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

	# Tactical Hitmarker 'X' Flash
	if hitmarker_timer > 0.0:
		var hm_size = 14.0
		var hm_gap = 5.0
		var hm_alpha = clamp(hitmarker_timer / 0.1, 0.0, 1.0)
		var hm_col = Color(1.0, 0.85, 0.2, hm_alpha)
		draw_line(center + Vector2(-hm_gap, -hm_gap), center + Vector2(-hm_size, -hm_size), hm_col, 2.5)
		draw_line(center + Vector2(hm_gap, -hm_gap), center + Vector2(hm_size, -hm_size), hm_col, 2.5)
		draw_line(center + Vector2(-hm_gap, hm_gap), center + Vector2(-hm_size, hm_size), hm_col, 2.5)
		draw_line(center + Vector2(hm_gap, hm_gap), center + Vector2(hm_size, hm_size), hm_col, 2.5)

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
			var target_node = t["node"]
			var display_name = t["name"]
			var is_relay = false
			if is_instance_valid(target_node):
				if "callsign_name" in target_node:
					display_name = target_node.callsign_name
				elif target_node.name.begins_with("JammingRelay"):
					display_name = "JAMMER TOWER"
				if display_name.contains("JAMMER") or display_name.contains("RELAY"):
					is_relay = true
			
			var b_size = clamp(3600.0 / max(dist_m, 10.0), 22.0, 64.0)
			if is_relay:
				_draw_diamond_box(s_pos, b_size * 1.3, Color(1.0, 0.25, 0.3, 1.0))
			else:
				_draw_bracket_box(s_pos, b_size, box_col)

			# Target Health Gauge (for damageable entities)
			if is_instance_valid(target_node):
				var cur_hp = target_node.get("health")
				var max_hp = target_node.get("max_health")
				if cur_hp != null and max_hp != null and max_hp > 0.0:
					var hp_ratio = clamp(float(cur_hp) / float(max_hp), 0.0, 1.0)
					var bar_w = max(b_size * 1.5, 46.0)
					var bar_h = 5.0
					var bar_x = s_pos.x - (bar_w * 0.5)
					var bar_y = s_pos.y - (b_size * 0.5) - 10.0
					draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), COLOR_PANEL_BG, true)
					draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), box_col * 0.7, false, 1.0)
					
					var fill_col = COLOR_RED if hp_ratio <= 0.5 else COLOR_GOLD
					if hp_ratio > 0.75:
						fill_col = Color(0.1, 0.95, 0.4, 0.95)
					if hp_ratio > 0.0:
						draw_rect(Rect2(bar_x + 1, bar_y + 1, (bar_w - 2) * hp_ratio, bar_h - 2), fill_col, true)
					
					var hp_txt = "%d%%" % int(hp_ratio * 100.0)
					draw_string(ThemeDB.fallback_font, Vector2(bar_x + bar_w + 4, bar_y + 5), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fill_col)
			
			# Range label
			var info_txt = "%s [%dm]" % [display_name, dist_m]
			if is_relay:
				info_txt = "◈ %s [%dm]" % [display_name, dist_m]
				draw_string(ThemeDB.fallback_font, Vector2(s_pos.x - 55, s_pos.y + b_size + 16), info_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1.0, 0.3, 0.35, 1.0))
			else:
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
			var is_offscreen_relay = t["name"].begins_with("JammingRelay")
			if is_offscreen_relay:
				draw_circle(edge_pos, 8.0, Color(1.0, 0.2, 0.25, 0.95))
				draw_circle(edge_pos, 3.5, Color(1.0, 0.9, 0.9, 1.0))
			else:
				draw_circle(edge_pos, 5.0, arrow_col)

func _draw_diamond_box(pos: Vector2, size: float, col: Color) -> void:
	var r = size * 0.6
	var pts = PackedVector2Array([
		Vector2(pos.x, pos.y - r),
		Vector2(pos.x + r, pos.y),
		Vector2(pos.x, pos.y + r),
		Vector2(pos.x - r, pos.y),
		Vector2(pos.x, pos.y - r)
	])
	draw_polyline(pts, col, 2.2)

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
# 5. Left Panel: Vital Systems & Flight Telemetry
# -----------------------------------------------------------------
func _draw_vital_systems(vp: Vector2) -> void:
	var panel_w = 275.0
	var panel_h = 196.0
	var px = 24.0
	var py = vp.y - 220.0

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
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 74), "HULL ARMOR %d%%" % round(h_pct * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, hull_col)
	draw_rect(Rect2(Vector2(px + 12, py + 80), Vector2(panel_w - 24, 10)), COLOR_CYAN_DIM * 0.4, true)
	draw_rect(Rect2(Vector2(px + 12, py + 80), Vector2((panel_w - 24) * h_pct, 10)), hull_col, true)

	# Aerospace Flight Telemetry
	var speed_kmh = round(ship.current_speed * 3.6)
	var mach = ship.current_speed / 340.0
	var alt_m = round(ship.global_position.y)
	var vs = round(ship.velocity.y)
	var vs_sign = "+" if vs >= 0 else ""
	var g_val = current_g_force
	var g_col = COLOR_RED if g_val > 7.0 else (COLOR_GOLD if g_val > 5.0 else COLOR_CYAN)
	
	var thrust_pct = round(clamp((ship.current_speed / max(1.0, ship.cruise_speed)) * 100.0, 0.0, 100.0))
	var thrust_tag = "A/B" if Input.is_key_pressed(KEY_SHIFT) else "MIL"

	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 112), "SPD: %4d km/h  |  M %.2f" % [speed_kmh, mach], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_CYAN)
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 132), "ALT: %4d m     |  V/S %s%d m/s" % [alt_m, vs_sign, vs], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_CYAN)
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 152), "G-LOAD: %+4.1f G  |  THR %d%% [%s]" % [g_val, thrust_pct, thrust_tag], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, g_col)
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 178), "[F1: Layout | H: Test Damage]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_CYAN_DIM)

# -----------------------------------------------------------------
# 6. Right Panel: Nitro & Ordnance Bays
# -----------------------------------------------------------------
func _draw_nitro_and_ordnance(vp: Vector2) -> void:
	var panel_w = 275.0
	var panel_h = 196.0
	var px = vp.x - panel_w - 24.0
	var py = vp.y - 220.0

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
		var is_reloading_this = (not is_loaded and i == telemetry.missiles_remaining)
		var b_col = COLOR_GOLD if is_loaded else (Color(0.2, 0.85, 1.0) if is_reloading_this else COLOR_CYAN_DIM * 0.4)
		
		draw_rect(Rect2(Vector2(bx, bay_y), Vector2(bay_w, bay_h)), COLOR_PANEL_BG, true)
		draw_rect(Rect2(Vector2(bx, bay_y), Vector2(bay_w, bay_h)), b_col, false, 1.5)
		
		if is_loaded:
			var m_label = "HP 0%d" % (i + 1)
			draw_string(ThemeDB.fallback_font, Vector2(bx + 6, bay_y + 16), m_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, b_col)
		elif is_reloading_this:
			var r_pct = clamp(telemetry.missile_reload_timer / max(telemetry.missile_reload_cooldown, 0.1), 0.0, 1.0)
			draw_rect(Rect2(Vector2(bx + 2, bay_y + 2), Vector2((bay_w - 4) * r_pct, bay_h - 4)), Color(0.0, 0.8, 1.0, 0.35), true)
			draw_string(ThemeDB.fallback_font, Vector2(bx + 2, bay_y + 16), "%d%%" % int(r_pct * 100), HORIZONTAL_ALIGNMENT_CENTER, bay_w - 4, 9, Color(0.2, 0.9, 1.0))
		else:
			draw_string(ThemeDB.fallback_font, Vector2(bx + 2, bay_y + 16), "EMPTY", HORIZONTAL_ALIGNMENT_CENTER, bay_w - 4, 8, COLOR_CYAN_DIM * 0.5)

	# Weapon Trigger Guide & Machine Gun (BRRR) Status
	var is_firing = (ship and ship.get("is_firing_gun") == true)
	var gun_col = COLOR_GOLD if is_firing else COLOR_CYAN
	var gun_txt = "ROTARY CANNON // BRRR [FIRING]" if is_firing else "ROTARY CANNON: 20mm [READY]"
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 134), gun_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, gun_col)
	draw_string(ThemeDB.fallback_font, Vector2(px + 12, py + 154), "[LMB / F: Gun (BRRR) | RMB / SPACE: Missile]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_CYAN_DIM)

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

# -----------------------------------------------------------------
# 8. Combat Status Event Toast
# -----------------------------------------------------------------
func _draw_combat_event_toast(center: Vector2) -> void:
	if combat_event_timer > 0.0 and combat_event_text != "":
		var toast_alpha = clamp(combat_event_timer / 0.4, 0.0, 1.0)
		var toast_col = Color(combat_event_color.r, combat_event_color.g, combat_event_color.b, toast_alpha)
		
		# Toast background pill
		var txt_w = 360.0
		var txt_h = 28.0
		var pill_rect = Rect2(Vector2(center.x - (txt_w * 0.5), center.y + 120.0), Vector2(txt_w, txt_h))
		draw_rect(pill_rect, Color(0.02, 0.04, 0.08, 0.85 * toast_alpha), true)
		draw_rect(pill_rect, Color(combat_event_color.r, combat_event_color.g, combat_event_color.b, 0.6 * toast_alpha), false, 1.2)
		draw_string(ThemeDB.fallback_font, Vector2(center.x - (txt_w * 0.5), center.y + 138.0), combat_event_text, HORIZONTAL_ALIGNMENT_CENTER, txt_w, 12, toast_col)

# -----------------------------------------------------------------
# 9. Tactical Mission Objectives Panel
# -----------------------------------------------------------------
func _draw_mission_objectives(vp: Vector2) -> void:
	if mission_objectives.is_empty():
		return
	
	var ox = 24.0
	var oy = vp.y - 195.0 - (mission_objectives.size() * 22.0)
	var ow = 320.0
	var oh = 28.0 + (mission_objectives.size() * 22.0)
	
	draw_rect(Rect2(Vector2(ox, oy), Vector2(ow, oh)), COLOR_PANEL_BG, true)
	draw_rect(Rect2(Vector2(ox, oy), Vector2(ow, oh)), COLOR_CYAN_DIM, false, 1.2)
	
	# Header
	var title_str = "TACTICAL OBJECTIVES // " + (mission_title if mission_title != "" else "SORTIE")
	draw_string(ThemeDB.fallback_font, Vector2(ox + 10, oy + 17), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GOLD)
	
	# Objective items
	for i in range(mission_objectives.size()):
		var obj = mission_objectives[i]
		var item_y = oy + 36.0 + (i * 22.0)
		var status = obj.get("status", "IN_PROGRESS")
		var icon = "[ ]"
		var col = COLOR_CYAN
		
		if status == "COMPLETED":
			icon = "[X]"
			col = COLOR_GREEN
		elif status == "FAILED":
			icon = "[!]"
			col = COLOR_RED
		
		var cur_v = obj.get("current_val", 0)
		var tgt_v = obj.get("target_val", 1)
		var prog_str = ""
		if tgt_v > 1:
			prog_str = " (%d/%d)" % [cur_v, tgt_v]
		
		var txt = "%s %s%s" % [icon, obj.get("text", ""), prog_str]
		draw_string(ThemeDB.fallback_font, Vector2(ox + 10, item_y), txt, HORIZONTAL_ALIGNMENT_LEFT, ow - 20, 10, col)

# -----------------------------------------------------------------
# 10. Radio Comms Transmission Banner
# -----------------------------------------------------------------
func _draw_radio_comms_banner(vp: Vector2) -> void:
	if current_radio_text == "":
		return
	
	var bw = 600.0
	var bh = 56.0
	var bx = (vp.x - bw) * 0.5
	var by = 58.0 # Just below the top compass ribbon
	
	# Background plate
	draw_rect(Rect2(Vector2(bx, by), Vector2(bw, bh)), Color(0.02, 0.05, 0.09, 0.94), true)
	draw_rect(Rect2(Vector2(bx, by), Vector2(bw, bh)), current_radio_color, false, 1.5)
	
	# Header bar
	draw_rect(Rect2(Vector2(bx, by), Vector2(bw, 18)), Color(current_radio_color.r * 0.25, current_radio_color.g * 0.25, current_radio_color.b * 0.25, 0.9), true)
	var header = "⚡ COMMS TRANSMISSION // %s [%s]" % [current_radio_speaker, current_radio_callsign]
	draw_string(ThemeDB.fallback_font, Vector2(bx + 12, by + 13), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, current_radio_color)
	
	# Message body
	draw_string(ThemeDB.fallback_font, Vector2(bx + 14, by + 36), current_radio_text, HORIZONTAL_ALIGNMENT_LEFT, bw - 28, 11, Color(0.92, 0.96, 1.0))

