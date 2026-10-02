class_name TargetBuoy
extends CharacterBody3D

## TargetBuoy: Holographic target practice buoy for Agility Mode.
## Stationary sensor drone that can be engaged with the rotary autocannon or missiles.
## Awards points and time reductions upon destruction.

signal destroyed(idx: int)

@export var target_index: int = 0
@export var max_health: float = 25.0

var current_health: float = 25.0
var is_destroyed: bool = false
var initial_pos_y: float = 0.0
var anim_time: float = 0.0

@onready var mesh_core: MeshInstance3D = $MeshCore
@onready var mesh_ring: MeshInstance3D = $MeshRing
@onready var label_dist: Label3D = $LabelDist

func _ready() -> void:
	current_health = max_health
	initial_pos_y = position.y
	# Ensure it is in target/enemies group for bullet collision
	add_to_group("targets")
	add_to_group("enemies")
	
	if label_dist:
		label_dist.text = "[ TARGET %02d ]" % (target_index + 1)

func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	anim_time += delta
	position.y = initial_pos_y + sin(anim_time * 2.0 + target_index) * 0.4
	if mesh_ring:
		mesh_ring.rotate_y(1.5 * delta)

func take_damage(amount: float, _attacker: Node = null) -> void:
	if is_destroyed:
		return
		
	current_health -= amount
	
	# Flash white/orange on hit
	if mesh_core and mesh_core.material_override:
		var mat = mesh_core.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 6.0
			var tw = create_tween()
			tw.tween_property(mat, "emission_energy_multiplier", 2.0, 0.12)
			
	if current_health <= 0.0:
		_destroy_buoy()

func _destroy_buoy() -> void:
	is_destroyed = true
	destroyed.emit(target_index)
	
	var am = get_tree().root.get_node_or_null("AgilityManager") if is_inside_tree() else null
	if am and am.has_method("register_target_destroyed"):
		am.register_target_destroyed(target_index)
		
	# Spawn explosion FX if scene exists
	var fx_scene = load("res://explosion_fx.tscn")
	if fx_scene:
		var fx = fx_scene.instantiate()
		get_parent().add_child(fx)
		fx.global_position = global_position
		
	# Shatter / vanish scale tween
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.finished.connect(queue_free)
