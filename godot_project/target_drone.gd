extends Node3D

@export var orbit_radius: float = 280.0
@export var orbit_speed: float = 0.35
@export var altitude: float = 75.0
@export var center_point: Vector3 = Vector3(0, 0, -350)
@export var health: float = 100.0

var angle: float = 0.0

func _ready() -> void:
	add_to_group("radar_targets")
	add_to_group("enemies")
	
	# Create visual mesh if none exists
	if get_child_count() == 0:
		var mi = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(5.0, 2.0, 8.0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.1, 0.15, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.2, 0.2, 1.0)
		mat.emission_energy_multiplier = 3.0
		box.material = mat
		mi.mesh = box
		add_child(mi)

func _process(delta: float) -> void:
	angle += orbit_speed * delta
	var target_x = center_point.x + cos(angle) * orbit_radius
	var target_z = center_point.z + sin(angle) * orbit_radius
	var target_y = altitude + sin(angle * 2.0) * 15.0
	
	var new_pos = Vector3(target_x, target_y, target_z)
	look_at(new_pos + Vector3(-sin(angle), 0, cos(angle)), Vector3.UP)
	global_position = new_pos

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		queue_free()

func get_save_data() -> Dictionary:
	return {
		"angle": angle,
		"health": health,
		"global_pos": [global_position.x, global_position.y, global_position.z]
	}

func restore_save_data(data: Dictionary) -> void:
	if data.has("angle"):
		angle = float(data["angle"])
	if data.has("health"):
		health = float(data["health"])
	if data.has("global_pos"):
		var p = data["global_pos"]
		global_position = Vector3(p[0], p[1], p[2])

