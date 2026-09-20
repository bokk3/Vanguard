extends Node3D

## TransportOlympus4: Heavy orbital cargo transport ascending along the catapult corridor.
## Mission-critical protected asset in Mission 03 (Operation Apex Liftoff).
## Features multi-layered shield/hull vitals, twin rocket plume emitters, and takes damage from enemy dive bombers.

signal damaged(cur_hull: float, max_hull: float, cur_shield: float, max_shield: float)
signal destroyed()

@export var max_hull: float = 500.0
@export var hull: float = 500.0
@export var max_shield: float = 300.0
@export var shield: float = 300.0
@export var forward_speed: float = 18.0

var is_alive: bool = true
var is_under_fire_warned: bool = false
var is_boosting: bool = false
var boost_climb_speed: float = 0.0

@onready var hit_box: Area3D = $HitBox
@onready var shield_mesh: MeshInstance3D = $ShieldBubble
@onready var thruster_left: CPUParticles3D = $ThrusterL
@onready var thruster_right: CPUParticles3D = $ThrusterR
@onready var engine_light: OmniLight3D = $EngineLight

var explosion_scene = preload("res://explosion_fx.tscn")

func _ready() -> void:
	add_to_group("radar_targets")
	add_to_group("friendlies")
	if shield_mesh:
		shield_mesh.visible = false

func _process(delta: float) -> void:
	if not is_alive:
		return
	
	var cur_z = global_position.z if is_inside_tree() else position.z
	if is_boosting:
		forward_speed = move_toward(forward_speed, 260.0, 80.0 * delta)
		boost_climb_speed = move_toward(boost_climb_speed, 110.0, 35.0 * delta)
		rotation.x = move_toward(rotation.x, deg_to_rad(24.0), 0.2 * delta)
		var move_step = (-transform.basis.z * forward_speed + Vector3.UP * boost_climb_speed) * delta
		if is_inside_tree():
			global_translate(move_step)
		else:
			position += move_step
	else:
		# Cruise along catapult corridor and hold at threshold (Z = -1050m) until booster ignition
		if cur_z > -1050.0:
			var move_step = -transform.basis.z * forward_speed * delta
			if is_inside_tree():
				global_translate(move_step)
			else:
				position += move_step
		else:
			if is_inside_tree():
				global_position.z = -1050.0
			else:
				position.z = -1050.0
	
	# Shield passive regeneration if not destroyed
	if shield < max_shield:
		shield = min(max_shield, shield + delta * 12.0)

func engage_booster_liftoff() -> void:
	if not is_alive or is_boosting:
		return
	is_boosting = true
	if engine_light:
		engine_light.light_color = Color(0.1, 0.9, 1.0)
		engine_light.light_energy = 25.0
		engine_light.omni_range = 100.0
	if thruster_left:
		thruster_left.amount = 64
		thruster_left.initial_velocity_min = 80.0
		thruster_left.initial_velocity_max = 130.0
	if thruster_right:
		thruster_right.amount = 64
		thruster_right.initial_velocity_min = 80.0
		thruster_right.initial_velocity_max = 130.0

func take_damage(amount: float) -> void:
	if not is_alive:
		return
	
	# 1. Damage Shields first
	if shield > 0.0:
		shield -= amount
		_flash_shield()
		if shield < 0.0:
			hull += shield # Apply remainder to hull
			shield = 0.0
	else:
		hull = max(0.0, hull - amount)
	
	damaged.emit(hull, max_hull, shield, max_shield)
	
	# Trigger "Under Fire" radio distress comms once when shields drop below 50%
	if not is_under_fire_warned and shield < (max_shield * 0.5):
		is_under_fire_warned = true
		var mm = get_tree().root.get_node_or_null("MissionManager") if (is_inside_tree() and get_tree() and get_tree().root) else null
		if mm and mm.has_method("queue_transmission"):
			mm.queue_transmission("OLYMPUS_4", "Vanguard Flight, we are taking kinetic hits on starboard shields! Get these gnats off us!", 4.5, "res://audio/comms/m03_olympus_under_fire.mp3")
	
	if hull <= 0.0:
		explode_transport()

func _flash_shield() -> void:
	if not shield_mesh:
		return
	shield_mesh.visible = true
	var t = create_tween()
	t.tween_property(shield_mesh, "transparency", 1.0, 0.25).from(0.35)
	t.tween_callback(func(): shield_mesh.visible = false)

func explode_transport() -> void:
	if not is_alive:
		return
	is_alive = false
	
	if explosion_scene:
		for offset in [Vector3(-8, 0, 0), Vector3(8, 0, 0), Vector3(0, 4, 10), Vector3(0, -4, -10)]:
			var exp_inst = explosion_scene.instantiate()
			var parent = get_parent() if get_parent() else (get_tree().root if is_inside_tree() else null)
			if parent:
				parent.add_child(exp_inst)
				exp_inst.global_position = global_position + offset
	
	destroyed.emit()
	
	# Notify MissionManager of failure
	var mm = get_tree().root.get_node_or_null("MissionManager") if (is_inside_tree() and get_tree() and get_tree().root) else null
	if mm and mm.has_method("fail_mission"):
		mm.fail_mission("TRANSPORT_LOST", "Catastrophic hull failure on Olympus-4. The orbital payload was destroyed.")
	
	queue_free()
