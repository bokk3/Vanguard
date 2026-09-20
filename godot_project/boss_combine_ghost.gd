extends CharacterBody3D

## BossCombineGhost: Elite adversary strike commander for Mission 04 (Operation Stratosphere Zero).
## Piloting a prototype F-82 Viper Supreme in stealth crimson livery.
## Features 6-DOF energy dogfighting AI, autocannon firing bursts, high-G evasion, and dynamic shield/hull vitals.

signal damaged(cur_hull: float, max_hull: float, cur_shield: float, max_shield: float)
signal destroyed()

@export var max_hull: float = 350.0
@export var hull: float = 350.0
@export var max_shield: float = 250.0
@export var shield: float = 250.0
@export var cruise_speed: float = 140.0
@export var max_boost_speed: float = 220.0
@export var turn_speed: float = 2.4

var current_speed: float = 140.0
var is_alive: bool = true
var target_player: Node3D = null

# AI State
enum State { PATROL, PURSUE, ATTACK_RUN, EVASIVE_BREAK, ZOOM_CLIMB }
var current_state: State = State.PURSUE
var state_timer: float = 0.0
var cannon_cooldown: float = 0.0

@onready var hit_box: Area3D = $HitBox
@onready var viper_model: Node3D = $ViperModelRoot
@onready var muzzle_left: Marker3D = $MuzzleL
@onready var muzzle_right: Marker3D = $MuzzleR

var bullet_scene = preload("res://bullet.tscn")
var explosion_scene = preload("res://explosion_fx.tscn")

func _ready() -> void:
	add_to_group("radar_targets")
	add_to_group("enemies")
	_apply_crimson_stealth_material()
	_acquire_player()

func _apply_crimson_stealth_material() -> void:
	var crimson_mat = StandardMaterial3D.new()
	crimson_mat.albedo_color = Color(0.72, 0.06, 0.09) # Stealth Crimson
	crimson_mat.metallic = 0.92
	crimson_mat.roughness = 0.22
	crimson_mat.emission_enabled = true
	crimson_mat.emission = Color(0.95, 0.12, 0.15)
	crimson_mat.emission_energy_multiplier = 2.2
	
	if viper_model:
		for mesh_inst in viper_model.find_children("*", "MeshInstance3D"):
			(mesh_inst as MeshInstance3D).material_override = crimson_mat

func _acquire_player() -> void:
	var scene = get_tree().current_scene
	if scene:
		target_player = scene.get_node_or_null("Spaceship")

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	state_timer -= delta
	cannon_cooldown -= delta
	
	if not is_instance_valid(target_player):
		_acquire_player()
	
	_update_ai_state(delta)
	_execute_maneuvers(delta)
	_evaluate_weapons_fire(delta)
	
	# Shield passive recharge
	if shield < max_shield:
		shield = min(max_shield, shield + delta * 15.0)

func _update_ai_state(delta: float) -> void:
	if state_timer <= 0.0:
		if not is_instance_valid(target_player):
			current_state = State.PATROL
			state_timer = 4.0
			return
		
		var dist = global_position.distance_to(target_player.global_position)
		if dist > 600.0:
			current_state = State.ZOOM_CLIMB
			state_timer = randf_range(3.0, 5.0)
		elif dist < 120.0:
			current_state = State.EVASIVE_BREAK
			state_timer = randf_range(2.0, 3.5)
		else:
			current_state = State.ATTACK_RUN if randf() > 0.4 else State.PURSUE
			state_timer = randf_range(4.0, 6.0)

func _execute_maneuvers(delta: float) -> void:
	var forward_dir = -global_transform.basis.z.normalized()
	var target_dir = forward_dir
	var target_speed = cruise_speed
	
	if is_instance_valid(target_player):
		var to_player = (target_player.global_position - global_position).normalized()
		match current_state:
			State.PURSUE:
				target_dir = to_player
				target_speed = cruise_speed * 1.2
			State.ATTACK_RUN:
				target_dir = to_player
				target_speed = max_boost_speed
			State.EVASIVE_BREAK:
				# Sharp high-G barrel roll away from player
				var away = -to_player
				target_dir = (away + global_transform.basis.x * 0.8 + global_transform.basis.y * 0.4).normalized()
				target_speed = max_boost_speed
				rotate_object_local(Vector3.FORWARD, delta * 3.5)
			State.ZOOM_CLIMB:
				# High-apogee energy climb
				target_dir = (Vector3.UP * 0.7 - global_transform.basis.z * 0.7).normalized()
				target_speed = max_boost_speed
			State.PATROL:
				target_dir = forward_dir
				target_speed = cruise_speed
	
	# Smooth rotational steering
	var angle_diff = forward_dir.angle_to(target_dir)
	if angle_diff > 0.02:
		var rot_axis = forward_dir.cross(target_dir).normalized()
		if rot_axis.length_squared() > 0.001:
			var max_rot = turn_speed * delta
			global_rotate(rot_axis, min(angle_diff, max_rot))
	
	current_speed = move_toward(current_speed, target_speed, 70.0 * delta)
	velocity = -global_transform.basis.z * current_speed
	move_and_slide()

func _evaluate_weapons_fire(delta: float) -> void:
	if not is_instance_valid(target_player) or current_state != State.ATTACK_RUN:
		return
	
	var forward_dir = -global_transform.basis.z.normalized()
	var to_player = (target_player.global_position - global_position).normalized()
	var angle = rad_to_deg(forward_dir.angle_to(to_player))
	var dist = global_position.distance_to(target_player.global_position)
	
	# Fire twin rotary cannon bursts if player is within 30-degree nose cone and under 400m
	if angle < 30.0 and dist < 420.0 and cannon_cooldown <= 0.0:
		cannon_cooldown = 0.12
		_fire_cannon_burst()

func _fire_cannon_burst() -> void:
	if not bullet_scene:
		return
	
	var parent_scene = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not parent_scene:
		return
	
	var forward = -global_transform.basis.z.normalized()
	for muzzle in [muzzle_left, muzzle_right]:
		if muzzle:
			var bullet = bullet_scene.instantiate()
			parent_scene.add_child(bullet)
			bullet.global_position = muzzle.global_position
			bullet.setup(self, forward, current_speed)

func take_damage(amount: float) -> void:
	if not is_alive:
		return
	
	# 1. Shields absorb damage first
	if shield > 0.0:
		shield -= amount
		if shield < 0.0:
			hull += shield
			shield = 0.0
	else:
		hull = max(0.0, hull - amount)
	
	damaged.emit(hull, max_hull, shield, max_shield)
	
	# Reactive high-G break when taking heavy fire
	if randf() > 0.6:
		current_state = State.EVASIVE_BREAK
		state_timer = 2.5
	
	if hull <= 0.0:
		explode_boss()

func explode_boss() -> void:
	if not is_alive:
		return
	is_alive = false
	
	# Multi-stage explosion cascade
	if explosion_scene:
		for offset in [Vector3(0, 0, 0), Vector3(3, 1, -2), Vector3(-3, -1, 2), Vector3(0, 2, 4)]:
			var exp_inst = explosion_scene.instantiate()
			var parent = get_tree().current_scene if get_tree().current_scene else get_parent()
			if parent:
				parent.add_child(exp_inst)
				exp_inst.global_position = global_position + offset
	
	destroyed.emit()
	queue_free()
