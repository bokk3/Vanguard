extends Node3D

## Bullet: High-velocity kinetic tracer round for the F-77 Rotary Machine Gun.
## Employs continuous raycast trajectory testing to eliminate tunneling at 650+ m/s,
## spawns impact sparks upon collision, and applies damage to target drones and enemies.

@export var speed: float = 650.0
@export var damage: float = 6.0
@export var max_lifetime: float = 2.2
@export var is_hostile: bool = false

var velocity: Vector3 = Vector3.ZERO
var shooter: Node3D = null
var lifetime: float = 0.0
var has_hit: bool = false

var spark_material: StandardMaterial3D

func _ready() -> void:
	spark_material = StandardMaterial3D.new()
	spark_material.albedo_color = Color(1.0, 0.8, 0.2, 1.0)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.7, 0.1, 1.0)
	spark_material.emission_energy_multiplier = 4.0
	
	if is_hostile:
		_apply_hostile_visuals()

func setup(from_shooter: Node3D, forward_dir: Vector3, initial_speed: float = 0.0, hostile: bool = false) -> void:
	shooter = from_shooter
	is_hostile = hostile
	# Projectile inherits forward ship speed + bullet muzzle velocity
	velocity = forward_dir.normalized() * (speed + max(initial_speed, 0.0))
	if is_inside_tree():
		look_at(global_position + velocity, Vector3.UP)
	if is_hostile:
		_apply_hostile_visuals()

func _apply_hostile_visuals() -> void:
	var tracer_mesh = get_node_or_null("TracerMesh") as MeshInstance3D
	if tracer_mesh:
		var red_mat = StandardMaterial3D.new()
		red_mat.albedo_color = Color(1.0, 0.2, 0.1, 1.0)
		red_mat.emission_enabled = true
		red_mat.emission = Color(1.0, 0.15, 0.05, 1.0)
		red_mat.emission_energy_multiplier = 5.5
		tracer_mesh.material_override = red_mat
	var light = get_node_or_null("TracerLight") as OmniLight3D
	if light:
		light.light_color = Color(1.0, 0.25, 0.1, 1.0)

func _physics_process(delta: float) -> void:
	if has_hit:
		return
	
	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()
		return
	
	var step = velocity * delta
	var current_pos = global_position
	var next_pos = current_pos + step
	
	# Raycast query for continuous collision detection
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(current_pos, next_pos)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	if shooter:
		var excludes: Array[RID] = []
		if shooter is CollisionObject3D:
			excludes.append(shooter.get_rid())
		for child in shooter.find_children("*", "CollisionObject3D", true, false):
			excludes.append((child as CollisionObject3D).get_rid())
		query.exclude = excludes
	
	var hit = space_state.intersect_ray(query)
	if not hit.is_empty():
		_handle_hit(hit.collider, hit.position, hit.normal)
	else:
		global_position = next_pos

func _handle_hit(collider: Object, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if has_hit:
		return
	has_hit = true
	
	# Check if collider or parent can take damage
	var target_node = collider as Node
	if target_node:
		var damage_receiver = target_node
		if not damage_receiver.has_method("take_damage") and damage_receiver.get_parent():
			damage_receiver = damage_receiver.get_parent()
		
		if damage_receiver.has_method("take_damage_from"):
			damage_receiver.take_damage_from(damage, shooter)
			_trigger_player_hitmarker()
		elif damage_receiver.has_method("take_damage"):
			damage_receiver.take_damage(damage)
			_trigger_player_hitmarker()
	
	# Spawn kinetic impact spark effect
	_spawn_impact_spark(hit_pos, hit_normal)
	queue_free()

func _trigger_player_hitmarker() -> void:
	if not shooter or is_hostile:
		return
	if shooter.has_method("trigger_hitmarker"):
		shooter.trigger_hitmarker()
		return
	var hud = get_tree().current_scene.find_child("TacticalOverlay", true, false) if (is_inside_tree() and get_tree() and get_tree().current_scene) else null
	if hud and hud.has_method("trigger_hitmarker"):
		hud.trigger_hitmarker()

func _spawn_impact_spark(pos: Vector3, normal: Vector3) -> void:
	var parent_node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not parent_node:
		return
	
	var sparks = CPUParticles3D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.amount = 12
	sparks.lifetime = 0.35
	sparks.mesh = SphereMesh.new()
	(sparks.mesh as SphereMesh).radius = 0.08
	(sparks.mesh as SphereMesh).height = 0.16
	(sparks.mesh as SphereMesh).material = spark_material
	sparks.direction = normal
	sparks.spread = 45.0
	sparks.initial_velocity_min = 6.0
	sparks.initial_velocity_max = 14.0
	sparks.color = Color(1.0, 0.8, 0.2, 1.0)
	
	parent_node.add_child(sparks)
	sparks.global_position = pos
	
	# Self-free particle node after emission finishes
	var timer = get_tree().create_timer(0.45)
	timer.timeout.connect(sparks.queue_free)
