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
@export var respawn_enabled: bool = true
@export var drone_type: String = "recon" # "recon", "skirmisher", "bomber"

var angle: float = 0.0
var is_alive: bool = true
var visual_root: Node3D = null
var mesh_instance: Node3D = null
var drone_material: StandardMaterial3D = null
var cached_materials: Array[StandardMaterial3D] = []
var hit_box: Area3D = null

var stalker_scene = preload("res://assets/meshes/vehicles/drone_stalker4_recon.glb")
var razor_scene = preload("res://assets/meshes/vehicles/drone_razor_skirmisher.glb")
var bomber_scene = preload("res://assets/meshes/vehicles/drone_strikefly_bomber.glb")
var explosion_scene = preload("res://explosion_fx.tscn")

func _ready() -> void:
	add_to_group("radar_targets")
	add_to_group("enemies")
	
	# 1. Instantiate bespoke Helion UCAV 3D model based on drone_type
	var target_scene = stalker_scene
	match drone_type.to_lower():
		"skirmisher", "interceptor", "razor":
			target_scene = razor_scene
		"bomber", "dive_bomber", "strikefly":
			target_scene = bomber_scene
		_:
			target_scene = stalker_scene
			
	if target_scene:
		visual_root = target_scene.instantiate()
		visual_root.name = "UCAV_VisualModel"
		add_child(visual_root)
		mesh_instance = visual_root
		_cache_drone_materials(visual_root)
	else:
		# Fallback if glb fails to load
		var mi = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(5.0, 2.0, 8.0)
		drone_material = StandardMaterial3D.new()
		drone_material.albedo_color = Color(0.95, 0.12, 0.16, 1.0)
		drone_material.metallic = 0.6
		drone_material.roughness = 0.3
		box.material = drone_material
		mi.mesh = box
		add_child(mi)
		mesh_instance = mi
		cached_materials.append(drone_material)
	
	# 2. Add Area3D HitBox for missile collision detection
	hit_box = Area3D.new()
	hit_box.name = "HitBox"
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(7.0, 3.5, 9.5)
	col.shape = shape
	hit_box.add_child(col)
	add_child(hit_box)

func _cache_drone_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for s in range(node.mesh.get_surface_count()):
			var mat = node.get_active_material(s)
			if mat is StandardMaterial3D:
				var dup = mat.duplicate()
				node.set_surface_override_material(s, dup)
				cached_materials.append(dup)
	for child in node.get_children():
		_cache_drone_materials(child)

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
	var hud = null
	if is_inside_tree() and get_tree() and get_tree().root:
		hud = get_tree().root.find_child("TacticalOverlay", true, false)
	if hud:
		if hud.has_method("trigger_hitmarker"):
			hud.trigger_hitmarker()
		if hud.has_method("notify_combat_event"):
			hud.notify_combat_event("// DIRECT HIT: -" + str(int(amount)) + " HP //", Color(1.0, 0.45, 0.2))
	
	if health <= 0.0:
		_on_destroyed()

func _flash_hit_reaction() -> void:
	if cached_materials.is_empty():
		return
	
	var tw = create_tween()
	for mat in cached_materials:
		mat.emission_enabled = true
		mat.emission = Color(2.5, 2.0, 1.2) # White-hot energy flash
		mat.emission_energy_multiplier = 6.0
		tw.parallel().tween_property(mat, "emission", Color(1.0, 0.15, 0.2), 0.22)
		tw.parallel().tween_property(mat, "emission_energy_multiplier", 3.0, 0.22)

func _on_destroyed() -> void:
	if not is_alive:
		return
	is_alive = false
	destroyed.emit()
	
	# Spawn explosion safely
	if explosion_scene:
		var boom = explosion_scene.instantiate()
		var spawn_parent: Node = null
		if is_inside_tree() and get_tree() and get_tree().current_scene:
			spawn_parent = get_tree().current_scene
		elif get_parent():
			spawn_parent = get_parent()
		elif is_inside_tree() and get_tree() and get_tree().root:
			spawn_parent = get_tree().root
			
		if spawn_parent:
			spawn_parent.add_child(boom)
			boom.global_position = global_position if is_inside_tree() else position
	
	# Notify HUD safely
	if is_inside_tree() and get_tree() and get_tree().root:
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
	
	if respawn_enabled:
		print(">>> DRONE DESTROYED! Respawn sequence initiated (4s)...")
		if is_inside_tree() and get_tree():
			get_tree().create_timer(4.0).timeout.connect(_respawn)
	else:
		print(">>> DRONE ELIMINATED! No respawn (Mission Objective).")
		if is_inside_tree() and get_tree():
			get_tree().create_timer(1.5).timeout.connect(func(): if is_instance_valid(self): queue_free())
		else:
			queue_free()

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
