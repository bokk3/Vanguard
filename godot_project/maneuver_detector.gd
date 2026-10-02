class_name ManeuverDetector
extends Node

## ManeuverDetector: Mathematical aerobatic flight recognition engine.
## Analyzes angular rates, roll accumulation, velocity slip angle, altitude,
## and control inputs to identify tactical maneuvers in real time.

signal maneuver_executed(type: String, score_bonus: int, time_bonus: float)

@export var ship: CharacterBody3D = null

# Roll Tracking (Barrel Roll)
var last_roll_angle: float = 0.0
var cumulative_roll: float = 0.0
var roll_window_timer: float = 0.0
var roll_in_progress: bool = false
const ROLL_THRESHOLD: float = 5.8 # ~332 degrees
const ROLL_TIME_LIMIT: float = 1.35 # seconds

# Knife-Edge Tracking
var knife_edge_timer: float = 0.0
var is_knife_edge_active: bool = false
const KNIFE_EDGE_HOLD_TIME: float = 0.65 # seconds

# High-G Vector Drift Tracking
var was_airbraking: bool = false
var drift_angle_peak: float = 0.0
var drift_detected: bool = false
var drift_cooldown: float = 0.0

# Deck Skim Tracking
var deck_skim_timer: float = 0.0
var is_deck_skimming: bool = false
const DECK_SKIM_ALTITUDE: float = 12.0 # meters
const DECK_SKIM_HOLD_TIME: float = 1.2 # seconds

# Maneuver Cooldowns to prevent spamming
var cooldowns: Dictionary = {
	"BARREL_ROLL": 0.0,
	"KNIFE_EDGE": 0.0,
	"HIGH_G_DRIFT": 0.0,
	"DECK_SKIM": 0.0
}

func _ready() -> void:
	if not ship:
		ship = get_parent() as CharacterBody3D

func _physics_process(delta: float) -> void:
	if not ship or not is_instance_valid(ship):
		return
		
	# Tick cooldowns
	for k in cooldowns.keys():
		if cooldowns[k] > 0.0:
			cooldowns[k] = max(0.0, cooldowns[k] - delta)
			
	var speed = ship.get("current_speed") if "current_speed" in ship else ship.velocity.length()
	if speed < 25.0:
		# Below stall or idle, reset active tracking
		_reset_states()
		return
		
	var basis = ship.global_transform.basis
	var forward = -basis.z.normalized()
	var right = basis.x.normalized()
	var up = basis.y.normalized()
	
	# -----------------------------------------------------------------
	# 1. BARREL ROLL RECOGNITION (Full 360° axial roll)
	# -----------------------------------------------------------------
	_process_barrel_roll(delta, right, up, speed)
	
	# -----------------------------------------------------------------
	# 2. KNIFE-EDGE FLIGHT (Wings vertical 80° - 100° sustained)
	# -----------------------------------------------------------------
	_process_knife_edge(delta, right, speed)
	
	# -----------------------------------------------------------------
	# 3. HIGH-G VECTOR DRIFT (Airbrake + Hard Yaw + Velocity Slip)
	# -----------------------------------------------------------------
	_process_vector_drift(delta, forward, speed)
	
	# -----------------------------------------------------------------
	# 4. LOW-ALTITUDE DECK SKIM (Deck < 12m at high speed)
	# -----------------------------------------------------------------
	_process_deck_skim(delta, speed)

func _process_barrel_roll(delta: float, right: Vector3, up: Vector3, speed: float) -> void:
	if cooldowns["BARREL_ROLL"] > 0.0:
		return
		
	var roll_input = Input.get_axis("roll_left", "roll_right")
	# Also account for mobile gyro roll
	if "mobile_control_active" in ship and ship.mobile_control_active:
		roll_input += float(ship.get("mobile_roll"))
		
	if abs(roll_input) > 0.45:
		if not roll_in_progress:
			roll_in_progress = true
			cumulative_roll = 0.0
			roll_window_timer = 0.0
			last_roll_angle = atan2(up.x, up.y)
			
		roll_window_timer += delta
		var current_angle = atan2(up.x, up.y)
		var diff = angle_difference(last_roll_angle, current_angle)
		cumulative_roll += abs(diff)
		last_roll_angle = current_angle
		
		if cumulative_roll >= ROLL_THRESHOLD:
			_trigger_maneuver("BARREL_ROLL", 450, 0.6)
			cooldowns["BARREL_ROLL"] = 2.0
			roll_in_progress = false
			cumulative_roll = 0.0
		elif roll_window_timer > ROLL_TIME_LIMIT:
			roll_in_progress = false
			cumulative_roll = 0.0
	else:
		if roll_in_progress:
			roll_window_timer += delta
			if roll_window_timer > 0.35:
				roll_in_progress = false
				cumulative_roll = 0.0

func _process_knife_edge(delta: float, right: Vector3, speed: float) -> void:
	if cooldowns["KNIFE_EDGE"] > 0.0:
		return
		
	# In Knife-Edge, ship's lateral axis (right vector) points up or down: |right.y| > 0.86 (~60° to 90°)
	var is_vertical_bank = abs(right.y) >= 0.82
	if is_vertical_bank and speed >= 45.0:
		knife_edge_timer += delta
		if knife_edge_timer >= KNIFE_EDGE_HOLD_TIME:
			_trigger_maneuver("KNIFE_EDGE", 500, 0.5)
			cooldowns["KNIFE_EDGE"] = 3.0
			knife_edge_timer = 0.0
	else:
		knife_edge_timer = max(0.0, knife_edge_timer - delta * 2.0)

func _process_vector_drift(delta: float, forward: Vector3, speed: float) -> void:
	if cooldowns["HIGH_G_DRIFT"] > 0.0:
		return
		
	var is_braking = Input.is_action_pressed("throttle_down")
	var is_boosting = Input.is_action_pressed("boost")
	if "mobile_control_active" in ship and ship.mobile_control_active:
		if ship.get("mobile_boost"): is_boosting = true
		
	var vel_norm = ship.velocity.normalized()
	if vel_norm.length_squared() > 0.1:
		var slip_angle_rad = forward.angle_to(vel_norm)
		var slip_deg = rad_to_deg(slip_angle_rad)
		
		if is_braking and slip_deg > 22.0:
			drift_detected = true
			drift_angle_peak = max(drift_angle_peak, slip_deg)
			
		if drift_detected and is_boosting and speed > 55.0:
			_trigger_maneuver("HIGH_G_DRIFT", 600, 0.7)
			cooldowns["HIGH_G_DRIFT"] = 2.5
			drift_detected = false
			drift_angle_peak = 0.0
	else:
		drift_detected = false

func _process_deck_skim(delta: float, speed: float) -> void:
	if cooldowns["DECK_SKIM"] > 0.0:
		return
		
	var alt = ship.global_position.y
	# If terrain floor elevation is known, check relative height
	var floor_y = ship.get("terrain_floor_y") if "terrain_floor_y" in ship else 0.0
	var relative_alt = alt - floor_y
	
	if relative_alt > 1.5 and relative_alt <= DECK_SKIM_ALTITUDE and speed >= 60.0:
		deck_skim_timer += delta
		if deck_skim_timer >= DECK_SKIM_HOLD_TIME:
			_trigger_maneuver("DECK_SKIM", 400, 0.5)
			cooldowns["DECK_SKIM"] = 4.0
			deck_skim_timer = 0.0
	else:
		deck_skim_timer = max(0.0, deck_skim_timer - delta * 1.5)

func _trigger_maneuver(type: String, score_bonus: int, time_bonus: float) -> void:
	maneuver_executed.emit(type, score_bonus, time_bonus)
	
	var am = get_tree().root.get_node_or_null("AgilityManager") if is_inside_tree() else null
	if am and am.has_method("register_maneuver"):
		am.register_maneuver(type, score_bonus, time_bonus)

func _reset_states() -> void:
	roll_in_progress = false
	cumulative_roll = 0.0
	knife_edge_timer = 0.0
	drift_detected = false
	deck_skim_timer = 0.0
