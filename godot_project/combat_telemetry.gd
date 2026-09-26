extends Node
class_name CombatTelemetry

signal shield_changed(current: float, max_val: float)
signal hull_changed(current: float, max_val: float)
signal nitro_changed(current: float, max_val: float, overheated: bool)
signal lock_state_changed(target: Node3D, progress: float, is_locked: bool)
signal missile_fired(remaining: int)
signal missile_replenished(remaining: int)
signal cannon_fired(remaining: int)
signal cannon_replenished(remaining: int)
signal ship_destroyed()

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
@export var missile_reload_cooldown: float = 6.5  ## Seconds to automatically restock 1 missile
var missiles_remaining: int = 4
var missile_reload_timer: float = 0.0

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
	_process_missile_reload(delta)
	_scan_radar_targets()
	_update_target_lock(delta)

# --------------------------------------------------------
# Shield & Damage Management
# --------------------------------------------------------
func apply_damage(amount: float) -> void:
	time_since_damage = 0.0
	
	# Shields divert absorbs 30% of incoming kinetic damage
	var effective_damage = amount
	if ship and "power_divert_mode" in ship and ship.power_divert_mode == "SHIELDS":
		effective_damage *= 0.70
	
	var had_shield = current_shield > 0.0
	if current_shield > 0.0:
		current_shield -= effective_damage
		if current_shield < 0.0:
			current_hull += current_shield # Apply overflow to hull
			current_shield = 0.0
	else:
		current_hull = max(0.0, current_hull - effective_damage)
	
	# Notify mobile cockpit and apply physical airframe shock if shields collapsed
	if had_shield and current_shield <= 0.0:
		if ship and "camera_shake_trauma" in ship:
			ship.camera_shake_trauma = max(ship.camera_shake_trauma, 0.45)
		var net_server = get_tree().root.get_node_or_null("NetworkControllerServer") if (is_inside_tree() and get_tree() and get_tree().root) else null
		if net_server and net_server.has_method("notify_combat_event") and ship:
			net_server.notify_combat_event(ship.player_id, "SHIELD_BROKEN")
	
	shield_changed.emit(current_shield, max_shield)
	hull_changed.emit(current_hull, max_hull)
	
	if current_hull <= 0.0:
		ship_destroyed.emit()

func _process_shield_recharge(delta: float) -> void:
	time_since_damage += delta
	var delay = shield_recharge_delay
	var rate = shield_recharge_rate
	
	# Shields Divert: cuts delay to 1s and boosts recharge rate 2.5x
	if ship and "power_divert_mode" in ship and ship.power_divert_mode == "SHIELDS":
		delay = 1.0
		rate *= 2.5
		
	if time_since_damage >= delay and current_shield < max_shield:
		current_shield = min(max_shield, current_shield + rate * delta)
		shield_changed.emit(current_shield, max_shield)

# --------------------------------------------------------
# Nitro / Afterburner Management
# --------------------------------------------------------
func request_afterburner(delta: float) -> bool:
	if is_overheated:
		return false
	
	var drain = nitro_drain_rate
	if ship and "power_divert_mode" in ship and ship.power_divert_mode == "ENGINES":
		drain *= 0.65 # 35% less nitro consumption in Engines mode
	
	if current_nitro > 0.0:
		current_nitro = max(0.0, current_nitro - drain * delta)
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
	var ship_boosting = ship.was_boosting if (ship and "was_boosting" in ship) else Input.is_key_pressed(KEY_SHIFT)
	if not ship_boosting and current_nitro < max_nitro:
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

func fire_cannon_round() -> bool:
	if cannon_rounds > 0:
		cannon_rounds -= 1
		cannon_fired.emit(cannon_rounds)
		return true
	return false

func refill_cannon(amount: int = 600) -> void:
	cannon_rounds = amount
	cannon_replenished.emit(cannon_rounds)

func _process_missile_reload(delta: float) -> void:
	if missiles_remaining < max_missiles:
		missile_reload_timer += delta
		if missile_reload_timer >= missile_reload_cooldown:
			missile_reload_timer = 0.0
			missiles_remaining += 1
			missile_replenished.emit(missiles_remaining)
			print(">>> MISSILE REPLENISHED! Current stock: ", missiles_remaining, "/", max_missiles)
	else:
		missile_reload_timer = 0.0

func refill_all_missiles() -> void:
	if missiles_remaining < max_missiles:
		missiles_remaining = max_missiles
		missile_reload_timer = 0.0
		missile_replenished.emit(missiles_remaining)
	refill_cannon(600)
	print(">>> ALL ORDNANCE REPLENISHED! Full stock: 4/4 missiles, 600 rounds")

func fire_cannon() -> bool:
	return fire_cannon_round()

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
	var was_locked = is_locked
	var duration = lock_duration
	if ship and "power_divert_mode" in ship and ship.power_divert_mode == "WEAPONS":
		duration *= 0.5 # 2x faster missile lock acquisition
		
	if current_target != null:
		lock_progress = min(1.0, lock_progress + (delta / duration))
		is_locked = (lock_progress >= 1.0)
	else:
		lock_progress = max(0.0, lock_progress - (delta * 2.0))
		is_locked = false
	
	if not was_locked and is_locked:
		var net_server = get_tree().root.get_node_or_null("NetworkControllerServer") if (is_inside_tree() and get_tree() and get_tree().root) else null
		if net_server and net_server.has_method("notify_combat_event") and ship:
			net_server.notify_combat_event(ship.player_id, "TARGET_LOCKED")
	
	lock_state_changed.emit(current_target, lock_progress, is_locked)

# -----------------------------------------------------------------------------
# Save / Restore Interface
# -----------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	return {
		"current_shield": current_shield,
		"current_hull": current_hull,
		"current_nitro": current_nitro,
		"is_overheated": is_overheated,
		"overheat_timer": overheat_timer,
		"missiles_remaining": missiles_remaining,
		"missile_reload_timer": missile_reload_timer
	}

func restore_save_data(data: Dictionary) -> void:
	if data.has("current_shield"):
		current_shield = float(data["current_shield"])
	if data.has("current_hull"):
		current_hull = float(data["current_hull"])
	if data.has("current_nitro"):
		current_nitro = float(data["current_nitro"])
	if data.has("is_overheated"):
		is_overheated = bool(data["is_overheated"])
	if data.has("overheat_timer"):
		overheat_timer = float(data["overheat_timer"])
	if data.has("missiles_remaining"):
		missiles_remaining = int(data["missiles_remaining"])
	if data.has("missile_reload_timer"):
		missile_reload_timer = float(data["missile_reload_timer"])
	
	shield_changed.emit(current_shield, max_shield)
	hull_changed.emit(current_hull, max_hull)
	nitro_changed.emit(current_nitro, max_nitro, is_overheated)
	missile_fired.emit(missiles_remaining)

