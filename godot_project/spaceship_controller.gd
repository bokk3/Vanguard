extends CharacterBody3D

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

@export_group("Camera Follow")
@export var camera_distance: float = 14.0
@export var camera_height: float = 4.0
@export var camera_lerp_speed: float = 8.0

var current_speed: float = 0.0
var mouse_input: Vector2 = Vector2.ZERO
var downward_velocity: float = 0.0

@onready var camera: Camera3D = get_node_or_null("../Camera3D")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print(">>> Project Vanguard Flight Controller Active!")
	print("Controls: W/S = Throttle, Shift = Afterburner, A/D = Roll, Q/E = Rudder, Mouse = Pitch/Yaw, ESC = Toggle Mouse")

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look / steering
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_input = event.relative
	
	# Escape toggles mouse capture
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# ----------------------------------------------------
	# 1. Throttle & Speed Management
	# ----------------------------------------------------
	var is_boosting = Input.is_key_pressed(KEY_SHIFT)
	var target_top_speed = boost_speed if is_boosting else cruise_speed

	if Input.is_key_pressed(KEY_W):
		current_speed = move_toward(current_speed, target_top_speed, acceleration * delta)
	elif Input.is_key_pressed(KEY_S):
		current_speed = move_toward(current_speed, min_speed, braking * delta)
	else:
		# Idle glide maintains cruising momentum
		pass

	# ----------------------------------------------------
	# 2. Rotational Steering (Pitch, Roll, Yaw)
	# ----------------------------------------------------
	var p_input: float = 0.0
	var r_input: float = 0.0
	var y_input: float = 0.0

	# Keyboard steering
	if Input.is_key_pressed(KEY_A):
		r_input += 1.0
	if Input.is_key_pressed(KEY_D):
		r_input -= 1.0

	if Input.is_key_pressed(KEY_Q):
		y_input += 1.0
	if Input.is_key_pressed(KEY_E):
		y_input -= 1.0

	if Input.is_key_pressed(KEY_UP):
		p_input -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		p_input += 1.0

	# Mouse steering contribution
	p_input += -mouse_input.y * mouse_sensitivity * 25.0
	y_input += -mouse_input.x * mouse_sensitivity * 18.0
	mouse_input = Vector2.ZERO # Consume mouse frame input

	# Apply rotation to local basis
	# Pitch: Rotate around local X axis
	rotate_object_local(Vector3.RIGHT, p_input * pitch_rate * delta)
	# Roll: Rotate around local Z axis
	rotate_object_local(Vector3.FORWARD, r_input * roll_rate * delta)
	# Yaw: Rotate around local Y axis
	rotate_object_local(Vector3.UP, y_input * yaw_rate * delta)

	# ----------------------------------------------------
	# 3. Aerodynamic Lift & Gravity Simulation
	# ----------------------------------------------------
	# Forward direction in Godot is -Z
	var forward_dir = -global_transform.basis.z.normalized()
	var forward_velocity = forward_dir * current_speed

	if enable_gravity:
		# Aerodynamic Lift curve:
		# If current_speed >= stall_speed: Lift is 100%, perfectly counteracting gravity.
		# If current_speed < stall_speed: Ship stalls, loses lift, and falls with gravity!
		var lift_ratio = clamp(current_speed / stall_speed, 0.0, 1.0)
		var uncompensated_gravity = (1.0 - lift_ratio) * gravity
		downward_velocity += uncompensated_gravity * delta
		# Air resistance terminal velocity cap
		downward_velocity = clamp(downward_velocity, 0.0, 60.0)
	else:
		downward_velocity = 0.0

	# Combine forward propulsion with gravity fall
	velocity = forward_velocity + Vector3(0, -downward_velocity, 0)

	move_and_slide()

	# ----------------------------------------------------
	# 4. Smooth 3rd Person Cinematic Chase Camera
	# ----------------------------------------------------
	if camera:
		# Camera targets position behind and slightly above the fighter
		var target_cam_pos = global_position + (global_transform.basis.z * camera_distance) + (global_transform.basis.y * camera_height)
		camera.global_position = camera.global_position.lerp(target_cam_pos, camera_lerp_speed * delta)
		
		# Look at ship's nose with lead
		var look_target = global_position + (forward_dir * 8.0)
		camera.look_at(look_target, global_transform.basis.y)
