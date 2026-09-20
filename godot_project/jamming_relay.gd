extends Node3D

## JammingRelay: Destructible ground-based electronic warfare transmitter.
## 45-meter tall tactical antenna spire with rotating ECM array,
## vertical sky-beam, pulsing crimson warning strobe, and hit detection.

signal damaged(cur_hp: float, max_hp: float)
signal destroyed(relay_node: Node3D)

@export var max_health: float = 150.0
@export var health: float = 150.0
@export var beacon_color: Color = Color(1.0, 0.15, 0.2)
@export var callsign_name: String = "EW JAMMING RELAY"

var is_alive: bool = true
var anim_time: float = 0.0

@onready var ecm_head: Node3D = find_child("ECMHead", true, false)
@onready var beacon_light: OmniLight3D = find_child("BeaconLight", true, false)
@onready var sky_beam: MeshInstance3D = find_child("SkyBeam", true, false)
@onready var hit_box: Area3D = find_child("HitBox", true, false)

var explosion_scene = preload("res://explosion_fx.tscn")

func _ready() -> void:
	add_to_group("radar_targets")
	add_to_group("enemies")
	
	if beacon_light:
		beacon_light.light_color = beacon_color
		beacon_light.light_energy = 4.0

func _process(delta: float) -> void:
	if not is_alive:
		return
	
	anim_time += delta
	
	# Rotate ECM transmitter head assembly
	if ecm_head:
		ecm_head.rotate_y(delta * 1.4)
	
	# Pulsing high-intensity warning strobe
	if beacon_light:
		var pulse = 3.0 + sin(anim_time * 12.0) * 2.2
		beacon_light.light_energy = pulse
	
	# Subtle breathing glow on the sky-beam
	if sky_beam:
		var mat = sky_beam.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.albedo_color.a = 0.28 + sin(anim_time * 4.0) * 0.12

func take_damage(amount: float) -> void:
	if not is_alive:
		return
	
	health = max(0.0, health - amount)
	damaged.emit(health, max_health)
	
	# Visual damage feedback: intense flash
	if beacon_light:
		beacon_light.light_energy = 12.0
	
	if health <= 0.0:
		explode_and_destroy()

func explode_and_destroy() -> void:
	if not is_alive:
		return
	is_alive = false
	
	# Spawn primary explosion at mid-mast
	if explosion_scene:
		var exp_inst = explosion_scene.instantiate()
		var parent_node = get_tree().current_scene if get_tree().current_scene else get_parent()
		if parent_node:
			parent_node.add_child(exp_inst)
			exp_inst.global_position = global_position + Vector3(0, 22, 0)
			
			# Secondary explosion near base after 0.2s
			get_tree().create_timer(0.2).timeout.connect(func():
				if is_instance_valid(parent_node):
					var exp2 = explosion_scene.instantiate()
					parent_node.add_child(exp2)
					exp2.global_position = global_position + Vector3(randf_range(-3, 3), 6, randf_range(-3, 3))
			)
	
	destroyed.emit(self)
	queue_free()
