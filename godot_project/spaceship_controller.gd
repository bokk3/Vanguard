extends CharacterBody3D

signal layout_changed(is_azerty: bool)

@export_group("Flight Dynamics")
@export var cruise_speed: float = 60.0        ## Normal cruising speed in m/s (~216 km/h)
@export var boost_speed: float = 120.0       ## Afterburner speed in m/s (~432 km/h)
@export var min_speed: float = 0.0           ## Full stop / idle speed
@export var acceleration: float = 40.0       ## Throttle response rate
@export var braking: float = 30.0            ## Airbrake rate

@export_group("Aerodynamic Steering (rad/s)")
@export var pitch_rate: float = 1.8          ## Pitch sensitivity (Nose up/down)
@export var roll_rate: float = 3.2           ## Roll sensitivity (Banking wings)
@export var yaw_rate: float = 1.0            ## Yaw sensitivity (Rudder turning)
@export var mouse_sensitivity: float = 0.0018

@export_group("Atmosphere & Gravity")
@export var gravity: float = 9.81            ## Earth gravity (m/s^2)
@export var stall_speed: float = 25.0        ## Below this speed, aerodynamic lift drops and ship falls!
@export var enable_gravity: bool = true

@export_group("Keyboard Layout")
@export var is_azerty: bool = false          ## Autodetected or toggled via F1

@export_group("Camera Follow")
@export var camera_distance: float = 14.0
@export var camera_height: float = 4.0
@export var camera_lerp_speed: float = 8.0

var current_speed: float = 0.0
var mouse_input: Vector2 = Vector2.ZERO
var downward_velocity: float = 0.0

var hardpoint_nodes: Array[Node3D] = []
var hardpoint_missiles: Array[Node3D] = []
const LAUNCH_SEQUENCE: Array[int] = [0, 3, 1, 2] # Left Outer, Right Outer, Left Inner, Right Inner

@onready var camera: Camera3D = get_node_or_null("../Camera3D")
@onready var telemetry: Node = $CombatTelemetry

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg:
		cfg.settings_changed.connect(_on_settings_changed)
		_apply_config(cfg)
	else:
		detect_keyboard_layout()
	print(">>> Project Vanguard Flight Controller Active!")
	print("Auto-detected Keyboard Layout: %s (Press F1 in-game to toggle)" % ("AZERTY" if is_azerty else "QWERTY"))
	
	_setup_weapon_hardpoints()
	if telemetry:
		telemetry.missile_fired.connect(_on_missile_fired_sync)
		telemetry.missile_replenished.connect(_on_missile_replenished_sync)
	
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.should_load_on_start:
		sm.call_deferred("apply_save_to_current_scene")
		sm.should_load_on_start = false

func _on_settings_changed() -> void:
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg:
		_apply_config(cfg)

func _apply_config(cfg: Node) -> void:
	is_azerty = cfg.is_azerty
	mouse_sensitivity = 0.0025 * cfg.mouse_sensitivity
	enable_gravity = cfg.enable_gravity

func detect_keyboard_layout() -> void:
	# 1. On Windows, check native user locale & keyboard preloads via reg query (<1ms)
	if OS.get_name() == "Windows":
		var out_locale: Array = []
		var err = OS.execute("reg", ["query", "HKCU\\Control Panel\\International", "/v", "LocaleName"], out_locale)
		if err == 0 and out_locale.size() > 0:
			var loc_str = str(out_locale[0]).to_upper()
			if "-BE" in loc_str or "-FR" in loc_str:
				is_azerty = true
				return
		
		var out_preload: Array = []
		err = OS.execute("reg", ["query", "HKCU\\Keyboard Layout\\Preload"], out_preload)
		if err == 0 and out_preload.size() > 0:
			var txt = str(out_preload[0]).to_lower()
			if "080c" in txt or "0813" in txt or "040c" in txt:
				is_azerty = true
				return

	# 2. Check DisplayServer keyboard layout if available
	var layout_idx = DisplayServer.keyboard_get_current_layout()
	if layout_idx >= 0:
		var layout_name = DisplayServer.keyboard_get_layout_name(layout_idx).to_lower()
		if "azerty" in layout_name or "belgian" in layout_name or "french" in layout_name:
			is_azerty = true
			return

	# 3. Check System Locale
	var locale = OS.get_locale().to_lower()
	if locale.ends_with("_be") or locale.begins_with("fr_") or locale == "fr":
		is_azerty = true
		return

	is_azerty = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_input = event.relative
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		is_azerty = not is_azerty
		var cfg = get_node_or_null("/root/ConfigManager")
		if cfg:
			cfg.reset_keybindings_preset(is_azerty)
		layout_changed.emit(is_azerty)
		print("Keyboard layout switched to: ", "AZERTY" if is_azerty else "QWERTY")
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var pause_menu = get_node_or_null("../HUD/PauseMenu")
		if pause_menu:
			pause_menu.pause_flight()
			get_viewport().set_input_as_handled()
			return
		else:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Test Damage Key: H
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		if telemetry:
			telemetry.apply_damage(25.0)
			print("Simulated Hull/Shield hit: -25 HP")

	# Fire Missile: Action fire_missile
	if event.is_action_pressed("fire_missile"):
		_fire_missile()

func _physics_process(delta: float) -> void:
	# ----------------------------------------------------
	# 1. Action-Based Throttle & Speed Management
	# ----------------------------------------------------
	var throttle_up = Input.is_action_pressed("throttle_up")
	var throttle_down = Input.is_action_pressed("throttle_down")

	var wants_boost = Input.is_action_pressed("boost")
	var can_boost = false
	if wants_boost and telemetry:
		can_boost = telemetry.request_afterburner(delta)
	
	var target_top_speed = boost_speed if can_boost else cruise_speed

	if throttle_up:
		current_speed = move_toward(current_speed, target_top_speed, acceleration * delta)
	elif throttle_down:
		current_speed = move_toward(current_speed, min_speed, braking * delta)

	# ----------------------------------------------------
	# 2. Rotational Steering (Pitch, Roll, Yaw)
	# ----------------------------------------------------
	# Left/Right arrow keys (or A/E) yaw, Q/D roll, Up/Down pitch
	var r_input: float = Input.get_axis("roll_right", "roll_left")
	var y_input: float = Input.get_axis("yaw_right", "yaw_left")
	var p_input: float = Input.get_axis("pitch_up", "pitch_down")

	var cfg = get_node_or_null("/root/ConfigManager")
	var pitch_invert = -1.0 if (cfg and cfg.invert_pitch) else 1.0
	p_input += -mouse_input.y * mouse_sensitivity * 25.0 * pitch_invert
	y_input += -mouse_input.x * mouse_sensitivity * 18.0
	mouse_input = Vector2.ZERO

	rotate_object_local(Vector3.RIGHT, p_input * pitch_rate * delta)
	rotate_object_local(Vector3.FORWARD, r_input * roll_rate * delta)
	rotate_object_local(Vector3.UP, y_input * yaw_rate * delta)

	# ----------------------------------------------------
	# 4. Aerodynamic Lift & Gravity Simulation
	# ----------------------------------------------------
	var forward_dir = -global_transform.basis.z.normalized()
	var forward_velocity = forward_dir * current_speed

	if enable_gravity:
		var lift_ratio = clamp(current_speed / stall_speed, 0.0, 1.0)
		var uncompensated_gravity = (1.0 - lift_ratio) * gravity
		downward_velocity += uncompensated_gravity * delta
		downward_velocity = clamp(downward_velocity, 0.0, 60.0)
	else:
		downward_velocity = 0.0

	velocity = forward_velocity + Vector3(0, -downward_velocity, 0)
	move_and_slide()

	# ----------------------------------------------------
	# 5. Smooth 3rd Person Chase Camera
	# ----------------------------------------------------
	if camera:
		var target_cam_pos = global_position + (global_transform.basis.z * camera_distance) + (global_transform.basis.y * camera_height)
		camera.global_position = camera.global_position.lerp(target_cam_pos, camera_lerp_speed * delta)
		var look_target = global_position + (forward_dir * 8.0)
		camera.look_at(look_target, global_transform.basis.y)

	# ----------------------------------------------------
	# 6. Beacon Proximity Resupply
	# ----------------------------------------------------
	if telemetry and telemetry.missiles_remaining < telemetry.max_missiles:
		var beacon = get_tree().current_scene.find_child("NavBeaconAlpha", true, false) if get_tree().current_scene else null
		if beacon and global_position.distance_to(beacon.global_position) < 75.0:
			telemetry.refill_all_missiles()
			var hud = get_node_or_null("../HUD/TacticalOverlay")
			if hud and hud.has_method("notify_combat_event"):
				hud.notify_combat_event("// NAV BEACON RESUPPLY // ALL ORDNANCE RESTOCKED //", Color(1.0, 0.84, 0.0))

# -----------------------------------------------------------------------------
# Weapon Hardpoints & Missile Launch System
# -----------------------------------------------------------------------------
func _setup_weapon_hardpoints() -> void:
	hardpoint_nodes.clear()
	hardpoint_missiles.clear()
	
	# Clean up any existing hardpoints if re-running
	for child in get_children():
		if child.name.begins_with("Hardpoint_"):
			child.queue_free()
	
	var station_positions = [
		Vector3(-3.2, -0.22, 1.2),  # Station 0: Left Outer
		Vector3(-2.2, -0.26, 0.4),  # Station 1: Left Inner
		Vector3(2.2, -0.26, 0.4),   # Station 2: Right Inner
		Vector3(3.2, -0.22, 1.2)    # Station 3: Right Outer
	]
	
	var missile_packed = load("res://Vanguard_Strike_Missile.fbx")
	var pylon_mat = StandardMaterial3D.new()
	pylon_mat.albedo_color = Color(0.12, 0.14, 0.16, 1.0)
	pylon_mat.metallic = 0.85
	pylon_mat.roughness = 0.35
	
	for i in range(station_positions.size()):
		var hp = Node3D.new()
		hp.name = "Hardpoint_0" + str(i + 1)
		hp.position = station_positions[i]
		add_child(hp)
		hardpoint_nodes.append(hp)
		
		# 1. Aerodynamic Pylon Mount
		var pylon = MeshInstance3D.new()
		pylon.name = "Pylon"
		var pylon_mesh = BoxMesh.new()
		pylon_mesh.size = Vector3(0.06, 0.12, 1.35)
		pylon_mesh.material = pylon_mat
		pylon.mesh = pylon_mesh
		pylon.position = Vector3(0, 0.05, 0)
		hp.add_child(pylon)
		
		# 2. Mounted Missile Visual
		if missile_packed:
			var m_inst = missile_packed.instantiate()
			m_inst.name = "MountedMissile"
			m_inst.position = Vector3(0, -0.10, -0.3)
			hp.add_child(m_inst)
			hardpoint_missiles.append(m_inst)
	
	# Initial sync with telemetry
	if telemetry:
		update_missile_racks(telemetry.missiles_remaining)

func update_missile_racks(remaining: int) -> void:
	var fired_count = 4 - remaining
	for i in range(hardpoint_missiles.size()):
		var is_fired = false
		for f in range(fired_count):
			if f < LAUNCH_SEQUENCE.size() and LAUNCH_SEQUENCE[f] == i:
				is_fired = true
				break
		if is_instance_valid(hardpoint_missiles[i]):
			hardpoint_missiles[i].visible = not is_fired

func _on_missile_fired_sync(remaining: int) -> void:
	update_missile_racks(remaining)

func _on_missile_replenished_sync(remaining: int) -> void:
	update_missile_racks(remaining)
	var hud = get_node_or_null("../HUD/TacticalOverlay")
	if hud and hud.has_method("notify_combat_event"):
		hud.notify_combat_event("// ORDNANCE ARMED: MISSILE RESTOCKED //", Color(0.1, 0.95, 0.4))

func _fire_missile() -> void:
	if not telemetry or telemetry.missiles_remaining <= 0:
		print("ORDNANCE DEPLETED! No missiles remaining on racks.")
		return
	
	var fired_count = 4 - telemetry.missiles_remaining
	var hp_idx = LAUNCH_SEQUENCE[fired_count % LAUNCH_SEQUENCE.size()]
	var hp_node = hardpoint_nodes[hp_idx]
	
	# Detach/hide mounted visual on that hardpoint
	if hp_idx < hardpoint_missiles.size() and is_instance_valid(hardpoint_missiles[hp_idx]):
		hardpoint_missiles[hp_idx].visible = false
	
	# Spawn live missile projectile
	var missile_scene = load("res://missile.tscn")
	if missile_scene:
		var missile = missile_scene.instantiate()
		var spawn_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
		if not spawn_parent:
			spawn_parent = get_tree().root
		spawn_parent.add_child(missile)
		missile.global_transform = hp_node.global_transform
		missile.launch(self, current_speed, telemetry.current_target)
		print(">>> MISSILE LAUNCHED from Station 0", hp_idx + 1, "! Remaining: ", telemetry.missiles_remaining - 1)
		
		# Notify HUD combat event
		var hud = get_node_or_null("../HUD/TacticalOverlay")
		if hud and hud.has_method("notify_combat_event"):
			hud.notify_combat_event("// MISSILE AWAY // TGT ACQUIRED", Color(0.0, 0.95, 1.0))
	
	# Decrement in telemetry
	telemetry.fire_missile()

# -----------------------------------------------------------------------------
# Save / Restore Interface
# -----------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation": [rotation.x, rotation.y, rotation.z],
		"current_speed": current_speed,
		"downward_velocity": downward_velocity
	}

func restore_save_data(data: Dictionary) -> void:
	if data.has("position"):
		var p = data["position"]
		global_position = Vector3(p[0], p[1], p[2])
	if data.has("rotation"):
		var r = data["rotation"]
		rotation = Vector3(r[0], r[1], r[2])
	if data.has("current_speed"):
		current_speed = float(data["current_speed"])
	if data.has("downward_velocity"):
		downward_velocity = float(data["downward_velocity"])
	
	if camera:
		var forward_dir = -global_transform.basis.z.normalized()
		camera.global_position = global_position + (global_transform.basis.z * camera_distance) + (global_transform.basis.y * camera_height)
		camera.look_at(global_position + (forward_dir * 8.0), global_transform.basis.y)
	
	if telemetry:
		update_missile_racks(telemetry.missiles_remaining)

