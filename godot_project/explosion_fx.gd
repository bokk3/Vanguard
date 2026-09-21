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
	
	audio_player.bus = "SFX"
	audio_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	audio_player.unit_size = 25.0
	audio_player.max_distance = 1200.0
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	
	var boom_sfx = load("res://audio/sfx/sfx_capital_ship_core_explosion.wav")
	if boom_sfx:
		audio_player.stream = boom_sfx
	audio_player.play()
