class_name GhostShip
extends Node3D

## GhostShip: Translucent holographic replay of the pilot's personal best flight trajectory.
## Plays back time-stamped position and orientation samples, toggleable in real time.

@export var samples: Array = []

var sample_idx: int = 0
var is_active: bool = false
var ghost_material: StandardMaterial3D = null

@onready var model_container: Node3D = $ModelContainer

func _ready() -> void:
	_setup_holographic_material()
	
	var am = get_node_or_null("/root/AgilityManager")
	if am:
		if not am.ghost_toggled.is_connected(_on_ghost_toggled):
			am.ghost_toggled.connect(_on_ghost_toggled)
		samples = am.ghost_playback_samples.duplicate(true)
		visible = am.ghost_enabled and samples.size() > 1
	else:
		visible = false

func _setup_holographic_material() -> void:
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(0.2, 0.8, 1.0, 0.4)
	ghost_material.emission_enabled = true
	ghost_material.emission = Color(0.15, 0.6, 1.0)
	ghost_material.emission_energy_multiplier = 2.0
	ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Apply to all child meshes in ModelContainer
	if model_container:
		for child in model_container.find_children("*", "MeshInstance3D", true, false):
			var m = child as MeshInstance3D
			if m and m.mesh:
				m.material_override = ghost_material

func _process(_delta: float) -> void:
	var am = get_node_or_null("/root/AgilityManager")
	if not am or not am.is_trial_active or not am.ghost_enabled:
		visible = false
		return
		
	if samples.is_empty():
		samples = am.ghost_playback_samples
		if samples.size() <= 1:
			visible = false
			return
			
	visible = true
	var cur_time = am.elapsed_time
	
	# Find sample pair surrounding cur_time
	while sample_idx < samples.size() - 2 and samples[sample_idx + 1]["time"] < cur_time:
		sample_idx += 1
		
	if sample_idx < samples.size() - 1:
		var s0 = samples[sample_idx]
		var s1 = samples[sample_idx + 1]
		var t0 = float(s0["time"])
		var t1 = float(s1["time"])
		var span = max(0.0001, t1 - t0)
		var factor = clamp((cur_time - t0) / span, 0.0, 1.0)
		
		global_position = (s0["pos"] as Vector3).lerp(s1["pos"] as Vector3, factor)
		
		# Smooth spherical/quaternion interpolation of rotation
		var b0 = Basis.from_euler(s0["rot"] as Vector3)
		var b1 = Basis.from_euler(s1["rot"] as Vector3)
		var q0 = Quaternion(b0)
		var q1 = Quaternion(b1)
		global_transform.basis = Basis(q0.slerp(q1, factor))
	elif samples.size() > 0:
		var last_s = samples[-1]
		global_position = last_s["pos"]
		global_rotation = last_s["rot"]

func _on_ghost_toggled(enabled: bool) -> void:
	visible = enabled and samples.size() > 1
