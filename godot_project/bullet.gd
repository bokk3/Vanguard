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

static var _cached_mesh: SphereMesh = null
static var _cached_hull_mat: StandardMaterial3D = null
static var _cached_shield_mat: StandardMaterial3D = null
static var _cached_hostile_mat: StandardMaterial3D = null
static var _proxy_sphere: SphereShape3D = null

var shooter_exclude_rids: Array[RID] = []

static func _init_cached_resources() -> void:
	if _proxy_sphere == null:
		_proxy_sphere = SphereShape3D.new()
		_proxy_sphere.radius = 0.85
	if _cached_mesh == null:
		_cached_mesh = SphereMesh.new()
		_cached_mesh.radius = 0.08
		_cached_mesh.height = 0.16
	if _cached_hull_mat == null:
		_cached_hull_mat = StandardMaterial3D.new()
		_cached_hull_mat.albedo_color = Color(1.0, 0.8, 0.2, 1.0)
		_cached_hull_mat.emission_enabled = true
		_cached_hull_mat.emission = Color(1.0, 0.7, 0.1, 1.0)
		_cached_hull_mat.emission_energy_multiplier = 4.0
	if _cached_shield_mat == null:
		_cached_shield_mat = StandardMaterial3D.new()
		_cached_shield_mat.albedo_color = Color(0.2, 0.85, 1.0, 1.0)
		_cached_shield_mat.emission_enabled = true
		_cached_shield_mat.emission = Color(0.1, 0.7, 1.0, 1.0)
		_cached_shield_mat.emission_energy_multiplier = 4.5
	if _cached_hostile_mat == null:
		_cached_hostile_mat = StandardMaterial3D.new()
		_cached_hostile_mat.albedo_color = Color(1.0, 0.2, 0.1, 1.0)
		_cached_hostile_mat.emission_enabled = true
		_cached_hostile_mat.emission = Color(1.0, 0.15, 0.05, 1.0)
		_cached_hostile_mat.emission_energy_multiplier = 5.5

func _ready() -> void:
	_init_cached_resources()
	if is_hostile:
		_apply_hostile_visuals()

func setup(from_shooter: Node3D, forward_dir: Vector3, initial_speed: float = 0.0, hostile: bool = false) -> void:
	_init_cached_resources()
	shooter = from_shooter
	is_hostile = hostile
	
	# Pre-cache shooter collision RIDs once upon spawn rather than traversing node hierarchy each physics tick
	shooter_exclude_rids.clear()
	if shooter and is_instance_valid(shooter):
		if shooter is CollisionObject3D:
			shooter_exclude_rids.append((shooter as CollisionObject3D).get_rid())
		for child in shooter.find_children("*", "CollisionObject3D", true, false):
			if child is CollisionObject3D:
				shooter_exclude_rids.append((child as CollisionObject3D).get_rid())
				
	# Projectile inherits forward ship speed + bullet muzzle velocity
	velocity = forward_dir.normalized() * (speed + max(initial_speed, 0.0))
	if is_inside_tree():
		look_at(global_position + velocity, Vector3.UP)
	if is_hostile:
		_apply_hostile_visuals()

func _apply_hostile_visuals() -> void:
	var tracer_mesh = get_node_or_null("TracerMesh") as MeshInstance3D
	if tracer_mesh:
		tracer_mesh.material_override = _cached_hostile_mat
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
	if not shooter_exclude_rids.is_empty():
		query.exclude = shooter_exclude_rids
	
	var hit = space_state.intersect_ray(query)
	if not hit.is_empty():
		_handle_hit(hit.collider, hit.position, hit.normal)
	else:
		# Kinetic proxy sphere sweep (0.85m margin) to prevent tunneling through thin meshes at 650+ m/s
		var shape_query = PhysicsShapeQueryParameters3D.new()
		shape_query.shape = _proxy_sphere
		shape_query.transform = Transform3D(Basis(), next_pos)
		shape_query.collide_with_areas = true
		shape_query.collide_with_bodies = true
		if not shooter_exclude_rids.is_empty():
			shape_query.exclude = shooter_exclude_rids

		var shape_hits = space_state.intersect_shape(shape_query, 1)
		if not shape_hits.is_empty():
			_handle_hit(shape_hits[0].collider, next_pos, -velocity.normalized())
		else:
			global_position = next_pos

func _handle_hit(collider: Object, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if has_hit:
		return
	has_hit = true
	
	var hit_shield = false
	# Check if collider or parent can take damage
	var target_node = collider as Node
	if target_node:
		var damage_receiver = target_node
		if not damage_receiver.has_method("take_damage") and damage_receiver.get_parent():
			damage_receiver = damage_receiver.get_parent()
		
		# Check if target has active shield
		if "shield" in damage_receiver and damage_receiver.shield > 0.0:
			hit_shield = true
		elif "telemetry" in damage_receiver and damage_receiver.telemetry and "current_shield" in damage_receiver.telemetry and damage_receiver.telemetry.current_shield > 0.0:
			hit_shield = true
		
		if damage_receiver.has_method("take_damage_from"):
			damage_receiver.take_damage_from(damage, shooter)
			_trigger_player_hitmarker()
		elif damage_receiver.has_method("take_damage"):
			damage_receiver.take_damage(damage)
			_trigger_player_hitmarker()
	
	# Spawn kinetic impact spark effect (cyan for shield, amber for hull)
	_spawn_impact_spark(hit_pos, hit_normal, hit_shield)
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

func _spawn_impact_spark(pos: Vector3, normal: Vector3, is_shield: bool = false) -> void:
	var parent_node = get_tree().current_scene if (is_inside_tree() and get_tree() and get_tree().current_scene) else get_parent()
	if not parent_node:
		return
	
	_init_cached_resources()
	var sparks = CPUParticles3D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 0.92
	sparks.amount = 14 if is_shield else 12
	sparks.lifetime = 0.32
	sparks.mesh = _cached_mesh
	sparks.material_override = _cached_shield_mat if is_shield else _cached_hull_mat
	sparks.direction = normal
	sparks.spread = 50.0 if is_shield else 40.0
	sparks.initial_velocity_min = 7.0
	sparks.initial_velocity_max = 16.0
	sparks.color = Color(0.2, 0.85, 1.0, 1.0) if is_shield else Color(1.0, 0.8, 0.2, 1.0)
	
	parent_node.add_child(sparks)
	sparks.global_position = pos
	
	# Self-free particle node after emission finishes
	if is_inside_tree() and get_tree():
		var timer = get_tree().create_timer(0.40)
		timer.timeout.connect(sparks.queue_free)
	else:
		sparks.queue_free()
