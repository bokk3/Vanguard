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

@onready var camera: Camera3D = get_node_or_null("../Camera3D")
@onready var telemetry: Node = $CombatTelemetry

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Auto-detect keyboard layout (AZERTY vs QWERTY)
	detect_keyboard_layout()
	print(">>> Project Vanguard Flight Controller Active!")
	print("Auto-detected Keyboard Layout: %s (Press F1 in-game to toggle)" % ("AZERTY" if is_azerty else "QWERTY"))

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
		layout_changed.emit(is_azerty)
		print("Keyboard layout switched to: ", "AZERTY" if is_azerty else "QWERTY")
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Test Damage Key: H
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		if telemetry:
			telemetry.apply_damage(25.0)
			print("Simulated Hull/Shield hit: -25 HP")

	# Fire Missile: Space or Enter
	if event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		if telemetry:
			if telemetry.fire_missile():
				print("MISSILE LAUNCHED! Remaining: ", telemetry.missiles_remaining)

func _physics_process(delta: float) -> void:
	# ----------------------------------------------------
	# 1. Adaptive Input Mapping (AZERTY vs QWERTY)
	# ----------------------------------------------------
	var throttle_up = false
	var throttle_down = false
	var roll_left = false
	var roll_right = false
	var yaw_left = false
	var yaw_right = false

	if is_azerty:
		throttle_up = Input.is_key_pressed(KEY_Z) or Input.is_physical_key_pressed(KEY_W)
		throttle_down = Input.is_key_pressed(KEY_S)
		roll_left = Input.is_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_A)
		roll_right = Input.is_key_pressed(KEY_D)
		yaw_left = Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_Q)
		yaw_right = Input.is_key_pressed(KEY_E)
	else:
		throttle_up = Input.is_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_W)
		throttle_down = Input.is_key_pressed(KEY_S)
		roll_left = Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_A)
		roll_right = Input.is_key_pressed(KEY_D)
		yaw_left = Input.is_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_Q)
		yaw_right = Input.is_key_pressed(KEY_E)

	# ----------------------------------------------------
	# 2. Nitro-Limited Throttle & Speed Management
	# ----------------------------------------------------
	var wants_boost = Input.is_key_pressed(KEY_SHIFT)
	var can_boost = false
	if wants_boost and telemetry:
		can_boost = telemetry.request_afterburner(delta)
	
	var target_top_speed = boost_speed if can_boost else cruise_speed

	if throttle_up:
		current_speed = move_toward(current_speed, target_top_speed, acceleration * delta)
	elif throttle_down:
		current_speed = move_toward(current_speed, min_speed, braking * delta)

	# ----------------------------------------------------
	# 3. Rotational Steering (Pitch, Roll, Yaw)
	# ----------------------------------------------------
	var p_input: float = 0.0
	var r_input: float = 0.0
	var y_input: float = 0.0

	if roll_left:
		r_input += 1.0
	if roll_right:
		r_input -= 1.0

	if yaw_left:
		y_input += 1.0
	if yaw_right:
		y_input -= 1.0

	if Input.is_key_pressed(KEY_UP):
		p_input -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		p_input += 1.0

	p_input += -mouse_input.y * mouse_sensitivity * 25.0
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
