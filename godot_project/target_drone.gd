extends Node3D

## TargetDrone: Autonomous orbiting training drone with collision hitbox, damage flash, explosion FX, and respawn loop.

signal damaged(cur_hp: float, max_hp: float)
signal destroyed()

@export var orbit_radius: float = 280.0
@export var orbit_speed: float = 0.35
@export var altitude: float = 75.0
@export var center_point: Vector3 = Vector3(0, 0, -350)
@export var max_health: float = 100.0
@export var health: float = 100.0

var angle: float = 0.0
var is_alive: bool = true
var mesh_instance: MeshInstance3D = null
var drone_material: StandardMaterial3D = null
var hit_box: Area3D = null

var explosion_scene = preload("res://explosion_fx.tscn")

func _ready() -> void:
	add_to_group("radar_targets")
	add_to_group("enemies")
	
	# 1. Create or bind visual mesh with emissive material
	if get_child_count() == 0:
		mesh_instance = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(5.0, 2.0, 8.0)
		
		drone_material = StandardMaterial3D.new()
		drone_material.albedo_color = Color(0.95, 0.12, 0.16, 1.0)
		drone_material.metallic = 0.6
		drone_material.roughness = 0.3
		drone_material.emission_enabled = true
		drone_material.emission = Color(1.0, 0.2, 0.2, 1.0)
		drone_material.emission_energy_multiplier = 3.0
		
		box.material = drone_material
		mesh_instance.mesh = box
		add_child(mesh_instance)
	else:
		mesh_instance = get_node_or_null("MeshInstance3D")
		if mesh_instance and mesh_instance.mesh and mesh_instance.mesh.material:
			drone_material = mesh_instance.mesh.material
	
	# 2. Add Area3D HitBox for missile collision detection
	hit_box = Area3D.new()
	hit_box.name = "HitBox"
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(6.0, 3.0, 9.0)
	col.shape = shape
	hit_box.add_child(col)
	add_child(hit_box)

func _process(delta: float) -> void:
	if not is_alive:
		return
	
	angle += orbit_speed * delta
	var target_x = center_point.x + cos(angle) * orbit_radius
	var target_z = center_point.z + sin(angle) * orbit_radius
	var target_y = altitude + sin(angle * 2.0) * 15.0
	
	var new_pos = Vector3(target_x, target_y, target_z)
	look_at(new_pos + Vector3(-sin(angle), 0, cos(angle)), Vector3.UP)
	global_position = new_pos

func take_damage(amount: float) -> void:
	if not is_alive:
		return
	
	health = max(0.0, health - amount)
	damaged.emit(health, max_health)
	
	# Visual hit flash reaction
	_flash_hit_reaction()
	
	# Notify Tactical HUD
	var hud = get_tree().root.find_child("TacticalOverlay", true, false)
	if hud:
		if hud.has_method("trigger_hitmarker"):
			hud.trigger_hitmarker()
		if hud.has_method("notify_combat_event"):
			hud.notify_combat_event("// DIRECT HIT: -" + str(int(amount)) + " HP //", Color(1.0, 0.45, 0.2))
	
	if health <= 0.0:
		_on_destroyed()

func _flash_hit_reaction() -> void:
	if not drone_material:
		return
	
	var tw = create_tween()
	drone_material.emission = Color(2.5, 2.0, 1.2) # White-hot energy flash
	drone_material.emission_energy_multiplier = 6.0
	tw.tween_property(drone_material, "emission", Color(1.0, 0.2, 0.2), 0.22)
	tw.parallel().tween_property(drone_material, "emission_energy_multiplier", 3.0, 0.22)

func _on_destroyed() -> void:
	is_alive = false
	destroyed.emit()
	
	# Spawn explosion
	if explosion_scene:
		var boom = explosion_scene.instantiate()
		var spawn_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
		if not spawn_parent:
			spawn_parent = get_tree().root
		spawn_parent.add_child(boom)
		boom.global_position = global_position
	
	# Notify HUD
	var hud = get_tree().root.find_child("TacticalOverlay", true, false)
	if hud and hud.has_method("notify_combat_event"):
		hud.notify_combat_event("// TARGET DESTROYED // SORTIE OBJECTIVE UPDATED //", Color(1.0, 0.85, 0.0))
	
	# Hide mesh, disable hitbox, remove from radar group
	if mesh_instance:
		mesh_instance.hide()
	if hit_box:
		hit_box.set_deferred("monitoring", false)
		hit_box.set_deferred("monitorable", false)
	if is_in_group("radar_targets"):
		remove_from_group("radar_targets")
	
	print(">>> DRONE DESTROYED! Respawn sequence initiated (4s)...")
	
	# Respawn after 4.0 seconds
	get_tree().create_timer(4.0).timeout.connect(_respawn)

func _respawn() -> void:
	health = max_health
	is_alive = true
	angle = randf_range(0.0, TAU)
	
	if mesh_instance:
		mesh_instance.show()
	if hit_box:
		hit_box.set_deferred("monitoring", true)
		hit_box.set_deferred("monitorable", true)
	if not is_in_group("radar_targets"):
		add_to_group("radar_targets")
	
	var hud = get_tree().root.find_child("TacticalOverlay", true, false)
	if hud and hud.has_method("notify_combat_event"):
		hud.notify_combat_event("// NEW CONTACT DETECTED // DRONE RE-ENGAGED //", Color(0.0, 0.95, 1.0))
	
	print(">>> DRONE RESPAWNED at angle: ", angle)

func get_save_data() -> Dictionary:
	return {
		"angle": angle,
		"health": health,
		"max_health": max_health,
		"is_alive": is_alive,
		"global_pos": [global_position.x, global_position.y, global_position.z]
	}

func restore_save_data(data: Dictionary) -> void:
	if data.has("angle"):
		angle = float(data["angle"])
	if data.has("max_health"):
		max_health = float(data["max_health"])
	if data.has("health"):
		health = float(data["health"])
	if data.has("is_alive"):
		is_alive = bool(data["is_alive"])
		if not is_alive:
			if mesh_instance: mesh_instance.hide()
			if is_in_group("radar_targets"): remove_from_group("radar_targets")
		else:
			if mesh_instance: mesh_instance.show()
			if not is_in_group("radar_targets"): add_to_group("radar_targets")
	if data.has("global_pos"):
		var p = data["global_pos"]
		global_position = Vector3(p[0], p[1], p[2])
