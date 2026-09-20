extends Node
class_name CombatTelemetry

signal shield_changed(current: float, max_val: float)
signal hull_changed(current: float, max_val: float)
signal nitro_changed(current: float, max_val: float, overheated: bool)
signal lock_state_changed(target: Node3D, progress: float, is_locked: bool)
signal missile_fired(remaining: int)

# 1. Health & Shields
@export_group("Vital Systems")
@export var max_shield: float = 100.0
@export var max_hull: float = 100.0
@export var shield_recharge_rate: float = 15.0
@export var shield_recharge_delay: float = 4.0

var current_shield: float = 100.0
var current_hull: float = 100.0
var time_since_damage: float = 10.0

# 2. Nitro / Afterburner Capacitor
@export_group("Nitro & Afterburner")
@export var max_nitro: float = 100.0
@export var nitro_drain_rate: float = 24.0      ## Drains in ~4.2 seconds of continuous boost
@export var nitro_recharge_rate: float = 18.0   ## Recharges in ~5.5 seconds
@export var overheat_lockout_time: float = 3.0  ## Cooldown penalty if completely depleted

var current_nitro: float = 100.0
var is_overheated: bool = false
var overheat_timer: float = 0.0

# 3. Weapons & Ammo
@export_group("Ammunition")
@export var max_missiles: int = 4
@export var cannon_rounds: int = 600
var missiles_remaining: int = 4

# 4. Target Acquisition & Radar
@export_group("Target Tracking")
@export var seeker_cone_deg: float = 35.0       ## Seeker lock cone half-angle
@export var lock_duration: float = 1.2          ## Seconds to achieve solid lock
@export var max_radar_range_m: float = 3000.0

var current_target: Node3D = null
var lock_progress: float = 0.0
var is_locked: bool = false
var detected_targets: Array = []

var ship: CharacterBody3D

func _ready() -> void:
	ship = get_parent() as CharacterBody3D
	current_shield = max_shield
	current_hull = max_hull
	current_nitro = max_nitro
	missiles_remaining = max_missiles

func _process(delta: float) -> void:
	_process_shield_recharge(delta)
	_process_nitro_recovery(delta)
	_scan_radar_targets()
	_update_target_lock(delta)

# --------------------------------------------------------
# Shield & Damage Management
# --------------------------------------------------------
func apply_damage(amount: float) -> void:
	time_since_damage = 0.0
	
	if current_shield > 0.0:
		current_shield -= amount
		if current_shield < 0.0:
			current_hull += current_shield # Apply overflow to hull
			current_shield = 0.0
	else:
		current_hull = max(0.0, current_hull - amount)
	
	shield_changed.emit(current_shield, max_shield)
	hull_changed.emit(current_hull, max_hull)

func _process_shield_recharge(delta: float) -> void:
	time_since_damage += delta
	if time_since_damage >= shield_recharge_delay and current_shield < max_shield:
		current_shield = min(max_shield, current_shield + shield_recharge_rate * delta)
		shield_changed.emit(current_shield, max_shield)

# --------------------------------------------------------
# Nitro / Afterburner Management
# --------------------------------------------------------
func request_afterburner(delta: float) -> bool:
	if is_overheated:
		return false
	
	if current_nitro > 0.0:
		current_nitro = max(0.0, current_nitro - nitro_drain_rate * delta)
		if current_nitro <= 0.0:
			is_overheated = true
			overheat_timer = overheat_lockout_time
		nitro_changed.emit(current_nitro, max_nitro, is_overheated)
		return true
	
	return false

func _process_nitro_recovery(delta: float) -> void:
	if is_overheated:
		overheat_timer -= delta
		if overheat_timer <= 0.0:
			is_overheated = false
		nitro_changed.emit(current_nitro, max_nitro, is_overheated)
		return

	# Passive recharge when not using boost
	if not Input.is_key_pressed(KEY_SHIFT) and current_nitro < max_nitro:
		current_nitro = min(max_nitro, current_nitro + nitro_recharge_rate * delta)
		nitro_changed.emit(current_nitro, max_nitro, is_overheated)

# --------------------------------------------------------
# Ordnance Management
# --------------------------------------------------------
func fire_missile() -> bool:
	if missiles_remaining > 0:
		missiles_remaining -= 1
		missile_fired.emit(missiles_remaining)
		return true
	return false

func fire_cannon() -> bool:
	if cannon_rounds > 0:
		cannon_rounds -= 1
		return true
	return false

# --------------------------------------------------------
# Radar & Target Lock-On System
# --------------------------------------------------------
func _scan_radar_targets() -> void:
	if not ship:
		return
	
	detected_targets.clear()
	var targets = get_tree().get_nodes_in_group("radar_targets")
	var ship_pos = ship.global_position
	var forward = -ship.global_transform.basis.z.normalized()
	
	var best_candidate: Node3D = null
	var min_angle = deg_to_rad(seeker_cone_deg)
	
	for t in targets:
		if not is_instance_valid(t) or t == ship:
			continue
		
		var t_pos = t.global_position
		var to_target = t_pos - ship_pos
		var dist = to_target.length()
		
		if dist > max_radar_range_m:
			continue
		
		var dir_to_target = to_target.normalized()
		var angle_to_forward = forward.angle_to(dir_to_target)
		
		# Compute horizontal azimuth in ship local coordinates (-180 to +180 deg)
		var local_dir = ship.global_transform.basis.inverse() * dir_to_target
		var azimuth_rad = atan2(local_dir.x, -local_dir.z) # 0 = forward, + = right, - = left
		
		var is_hostile = t.is_in_group("enemies")
		var target_info = {
			"node": t,
			"name": t.name,
			"distance": dist,
			"azimuth_deg": rad_to_deg(azimuth_rad),
			"elevation_deg": rad_to_deg(asin(clamp(local_dir.y, -1.0, 1.0))),
			"angle_off_nose": rad_to_deg(angle_to_forward),
			"is_hostile": is_hostile,
			"world_pos": t_pos
		}
		detected_targets.append(target_info)
		
		# Evaluate potential lock candidate (hostile inside seeker cone)
		if is_hostile and angle_to_forward < min_angle:
			min_angle = angle_to_forward
			best_candidate = t
	
	current_target = best_candidate

func _update_target_lock(delta: float) -> void:
	if current_target != null:
		lock_progress = min(1.0, lock_progress + (delta / lock_duration))
		is_locked = (lock_progress >= 1.0)
	else:
		lock_progress = max(0.0, lock_progress - (delta * 2.0))
		is_locked = false
	
	lock_state_changed.emit(current_target, lock_progress, is_locked)
