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
@export var forward_speed: float = 35.0

var is_alive: bool = true
var is_under_fire_warned: bool = false

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
	
	# Slowly advance forward along the catapult track
	global_translate(-global_transform.basis.z * forward_speed * delta)
	
	# Shield passive regeneration if not destroyed
	if shield < max_shield:
		shield = min(max_shield, shield + delta * 12.0)

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
		var mm = get_node_or_null("/root/MissionManager")
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
			get_parent().add_child(exp_inst)
			exp_inst.global_position = global_position + offset
	
	destroyed.emit()
	
	# Notify MissionManager of failure
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("fail_mission"):
		mm.fail_mission("TRANSPORT_LOST", "Catastrophic hull failure on Olympus-4. The orbital payload was destroyed.")
	
	queue_free()
