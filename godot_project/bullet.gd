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

static func _init_cached_resources() -> void:
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

func _ready() -> void:
	_init_cached_resources()
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
