extends Area3D

## GuidedStrikeMissile: High-velocity homing missile with particle exhaust and impact detonation.

@export var damage: float = 50.0
@export var max_speed: float = 210.0
@export var acceleration: float = 90.0
@export var turn_rate: float = 4.2
@export var max_lifetime: float = 6.5

var target: Node3D = null
var shooter: Node3D = null
var current_speed: float = 60.0
var lifetime: float = 0.0
var has_detonated: bool = false

@onready var flame_particles: CPUParticles3D = $RocketFlame
@onready var smoke_particles: CPUParticles3D = $SmokeTrail
@onready var exhaust_light: OmniLight3D = $ExhaustLight
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer3D

var explosion_scene = preload("res://explosion_fx.tscn")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_play_launch_sound()

func launch(from_shooter: Node3D, initial_speed: float, target_node: Node3D = null) -> void:
	shooter = from_shooter
	current_speed = max(initial_speed + 20.0, 45.0)
	target = target_node

func _physics_process(delta: float) -> void:
	if has_detonated:
		return
	
	lifetime += delta
	if lifetime >= max_lifetime:
		detonate(null)
		return
	
	# 1. Rocket motor acceleration
	current_speed = move_toward(current_speed, max_speed, acceleration * delta)
	
	# 2. Homing Guidance
	if is_instance_valid(target):
		var target_pos = target.global_position
		# Slight lead toward center if target is drone
		var to_target = (target_pos - global_position).normalized()
		var forward = -global_transform.basis.z.normalized()
		
		var angle_diff = forward.angle_to(to_target)
		if angle_diff > 0.01:
			var rot_axis = forward.cross(to_target).normalized()
			if rot_axis.length_squared() > 0.001:
				var max_rot = turn_rate * delta
				var actual_rot = min(angle_diff, max_rot)
				global_rotate(rot_axis, actual_rot)
	
	# 3. Advance position forward along -Z
	var forward_dir = -global_transform.basis.z.normalized()
	global_position += forward_dir * current_speed * delta

func _on_body_entered(body: Node) -> void:
	if body == shooter or has_detonated:
		return
	detonate(body)

func _on_area_entered(area: Area3D) -> void:
	if area == shooter or has_detonated:
		return
	detonate(area)

func detonate(hit_object: Node) -> void:
	if has_detonated:
		return
	has_detonated = true
	
	# Apply damage if possible
	if hit_object != null:
		var candidate = hit_object
		if not candidate.has_method("take_damage") and candidate.get_parent():
			candidate = candidate.get_parent()
		
		if candidate.has_method("take_damage"):
			candidate.take_damage(damage)
			print(">>> MISSILE IMPACT: Dealt ", damage, " HP to ", candidate.name)
			var mm = get_node_or_null("/root/MissionManager")
			if mm and mm.has_method("record_hit"):
				mm.record_hit(true)
	
	# Spawn explosion FX into root
	if explosion_scene:
		var boom = explosion_scene.instantiate()
		var spawn_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
		if not spawn_parent:
			spawn_parent = get_tree().root
		spawn_parent.add_child(boom)
		boom.global_position = global_position
	
	queue_free()

func _play_launch_sound() -> void:
	if not audio_player:
		return
	
	# Procedural whoosh sound for rocket launch
	var sample_rate = 22050
	var duration = 0.5
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var env = sin(clamp(t / duration, 0.0, 1.0) * PI)
		var noise = randf_range(-1.0, 1.0)
		var whoosh = sin(t * 260.0 * TAU) * 0.4
		var sample = (noise * 0.6 + whoosh * 0.4) * env
		var val = int(clamp(sample, -1.0, 1.0) * 127.0 + 128.0)
		data[i] = val
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	
	audio_player.stream = wav
	audio_player.unit_size = 18.0
	audio_player.max_distance = 450.0
	audio_player.play()
