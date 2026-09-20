extends Node3D

## JammingRelay: Destructible ground-based electronic warfare transmitter.
## Built from modular CAD composite wall units with pulsing high-intensity red beacon.
## Implements take_damage() for 20mm rotary cannon and Vanguard Strike Missiles.

signal damaged(cur_hp: float, max_hp: float)
signal destroyed(relay_node: Node3D)

@export var max_health: float = 120.0
@export var health: float = 120.0
@export var beacon_color: Color = Color(1.0, 0.15, 0.2)

var is_alive: bool = true
var anim_time: float = 0.0

@onready var beacon_light: OmniLight3D = $BeaconLight
@onready var hit_box: Area3D = $HitBox
@onready var mesh_root: Node3D = $MeshRoot

var explosion_scene = preload("res://explosion_fx.tscn")

func _ready() -> void:
	add_to_group("radar_targets")
	add_to_group("enemies")
	
	if beacon_light:
		beacon_light.light_color = beacon_color
		beacon_light.light_energy = 3.5

func _process(delta: float) -> void:
	if not is_alive:
		return
	
	anim_time += delta
	# Pulsing warning strobe on the antenna mast (2.5 Hz pulse)
	if beacon_light:
		var pulse = 2.0 + sin(anim_time * 15.0) * 1.8
		beacon_light.light_energy = pulse

func take_damage(amount: float) -> void:
	if not is_alive:
		return
	
	health = max(0.0, health - amount)
	damaged.emit(health, max_health)
	
	# Visual damage flash: brighten beacon temporarily
	if beacon_light:
		beacon_light.light_energy = 8.0
	
	if health <= 0.0:
		explode_and_destroy()

func explode_and_destroy() -> void:
	if not is_alive:
		return
	is_alive = false
	
	# Spawn explosion particles
	if explosion_scene:
		var exp_inst = explosion_scene.instantiate()
		var parent_node = get_tree().current_scene if get_tree().current_scene else get_parent()
		if parent_node:
			parent_node.add_child(exp_inst)
			exp_inst.global_position = global_position + Vector3(0, 10, 0)
	
	destroyed.emit(self)
	queue_free()
