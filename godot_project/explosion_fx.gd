extends Node3D

## ExplosionFX: Cinematic 3D explosion with debris, shockwave ring, dynamic light, and procedural audio.

@onready var light: OmniLight3D = $Light
@onready var particles: CPUParticles3D = $DebrisParticles
@onready var shockwave: MeshInstance3D = $Shockwave
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer3D

func _ready() -> void:
	# Trigger particles
	if particles:
		particles.emitting = true
	
	# Animate light flash
	if light:
		var tw_light = create_tween()
		tw_light.tween_property(light, "light_energy", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Animate shockwave expansion & fade
	if shockwave:
		shockwave.scale = Vector3(0.2, 0.2, 0.2)
		var mat = shockwave.get_surface_override_material(0)
		if mat:
			mat = mat.duplicate()
			shockwave.set_surface_override_material(0, mat)
		
		var tw_shock = create_tween().set_parallel(true)
		tw_shock.tween_property(shockwave, "scale", Vector3(9.0, 9.0, 9.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if mat:
			tw_shock.tween_property(mat, "albedo_color:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Play procedural explosion sound
	_play_explosion_sound()
	
	# Auto clean-up after FX completes
	get_tree().create_timer(1.6).timeout.connect(queue_free)

func _play_explosion_sound() -> void:
	if not audio_player:
		return
	
	# Synthesize a gritty low-frequency explosion rumble
	var sample_rate = 22050
	var duration = 0.8
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var env = exp(-t * 5.0) # Fast decay
		var noise = randf_range(-1.0, 1.0)
		var low_rumble = sin(t * 120.0 * TAU) * 0.6
		var sample = (noise * 0.4 + low_rumble * 0.6) * env
		var val = int(clamp(sample, -1.0, 1.0) * 127.0 + 128.0)
		data[i] = val
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	
	audio_player.stream = wav
	audio_player.unit_size = 25.0
	audio_player.max_distance = 600.0
	audio_player.play()
