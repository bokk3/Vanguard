class_name AgilityGate
extends Area3D

## AgilityGate: Interactive 3D holographic waypoint gate.
## Detects sub-meter radial bullseye entry, required wing roll orientation,
## and entry speed, triggering audio chimes and notifying AgilityManager.

signal gate_cleared(gate_idx: int, radial_dist: float, orientation_match: bool)

@export var gate_index: int = 0
@export_enum("ANY", "HORIZONTAL", "VERTICAL", "DIHEDRAL_45") var required_orientation: String = "ANY"
@export var min_required_speed: float = 0.0
@export var gate_radius: float = 6.0

@onready var ring_mesh: MeshInstance3D = $RingMesh
@onready var inner_reticle: MeshInstance3D = $InnerReticle
@onready var gate_label: Label3D = $GateLabel
@onready var pass_audio: AudioStreamPlayer3D = $PassAudio
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var is_cleared: bool = false
var default_color: Color = Color(0.96, 0.62, 0.04, 0.85) # Tactical amber
var active_color: Color = Color(0.2, 0.85, 0.55, 0.95)   # Tactical emerald on pass

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_mask = 1 # Player layer
	
	body_entered.connect(_on_body_entered)
	_setup_visuals()

func _setup_visuals() -> void:
	if gate_label:
		gate_label.text = "GATE %02d" % (gate_index + 1)
		match required_orientation:
			"VERTICAL": gate_label.text += " [KNIFE-EDGE]"
			"DIHEDRAL_45": gate_label.text += " [45° BANK]"
			"HORIZONTAL": gate_label.text += " [LEVEL]"
			_:
				if min_required_speed > 0.0:
					gate_label.text += " [SPEED %d+]" % int(min_required_speed)

	_apply_material_color(default_color)

var _cached_mat: StandardMaterial3D = null

func _apply_material_color(col: Color) -> void:
	if ring_mesh:
		if not _cached_mat:
			_cached_mat = StandardMaterial3D.new()
			_cached_mat.emission_enabled = true
			_cached_mat.emission_energy_multiplier = 2.5
			_cached_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_cached_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			ring_mesh.material_override = _cached_mat
		_cached_mat.albedo_color = col
		_cached_mat.emission = col

func _exit_tree() -> void:
	_cached_mat = null

func _on_body_entered(body: Node3D) -> void:
	if is_cleared:
		return
	if not body.is_in_group("player") and not body.name.begins_with("Spaceship"):
		return
		
	is_cleared = true
	
	# 1. Calculate radial deviation from gate center
	var local_pt = to_local(body.global_position)
	var radial_dist = Vector2(local_pt.x, local_pt.y).length()
	
	# 2. Check Orientation requirement
	var orientation_match = _check_orientation(body)
	
	# 3. Check speed requirement if set
	var speed = body.get("current_speed") if "current_speed" in body else 60.0
	if min_required_speed > 0.0 and speed < min_required_speed:
		orientation_match = false
		
	# 4. Trigger pass presentation
	_play_pass_fx(radial_dist, orientation_match)
	
	gate_cleared.emit(gate_index, radial_dist, orientation_match)
	
	var am = get_tree().root.get_node_or_null("AgilityManager") if is_inside_tree() else null
	if am and am.has_method("on_gate_passed"):
		am.on_gate_passed(gate_index, radial_dist, orientation_match)

func _check_orientation(body: Node3D) -> bool:
	if required_orientation == "ANY":
		return true
		
	var b_right = body.global_transform.basis.x.normalized()
	match required_orientation:
		"VERTICAL":
			# Wings vertical: |b_right.y| > 0.75 (~48° to 90°)
			return abs(b_right.y) >= 0.72
		"HORIZONTAL":
			# Wings level: |b_right.y| < 0.35 (~0° to 20°)
			return abs(b_right.y) <= 0.38
		"DIHEDRAL_45":
			# Banked around 45°: |b_right.y| between 0.45 and 0.85
			return abs(b_right.y) >= 0.40 and abs(b_right.y) <= 0.88
	return true

func _play_pass_fx(radial_dist: float, orientation_match: bool) -> void:
	var flash_col = active_color if orientation_match else Color(0.9, 0.2, 0.2, 0.9)
	if radial_dist <= 1.8 and orientation_match:
		flash_col = Color(1.0, 0.88, 0.2, 1.0) # Golden flash for Perfect Apex!
		
	_apply_material_color(flash_col)
	
	# Animate gate scale pulse
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", scale * 1.15, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "scale", scale, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if ring_mesh and ring_mesh.material_override:
		tw.tween_property(ring_mesh.material_override, "albedo_color:a", 0.4, 0.5)
	
	if pass_audio:
		pass_audio.pitch_scale = 1.2 if radial_dist <= 1.8 else 1.0
		pass_audio.play()

func reset_gate() -> void:
	is_cleared = false
	scale = Vector3.ONE
	_apply_material_color(default_color)
