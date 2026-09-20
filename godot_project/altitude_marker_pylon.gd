extends Node3D

## AltitudeMarkerPylon: 120m aerospace telemetry mast providing visual altitude
## calibration bands (40m, 80m, 120m) and synchronized aviation strobes.

@export var mast_height: float = 120.0
@export var strobe_rate_hz: float = 1.2

var time_accum: float = 0.0
@onready var top_strobe: OmniLight3D = find_child("TopStrobe", true, false)
@onready var mid_beacon_1: OmniLight3D = find_child("MidBeacon1", true, false)
@onready var mid_beacon_2: OmniLight3D = find_child("MidBeacon2", true, false)

func _ready() -> void:
	# Randomize initial phase slightly so multiple pylons don't look completely robotic
	time_accum = randf_range(0.0, 1.0)

func _process(delta: float) -> void:
	time_accum += delta * strobe_rate_hz
	
	# Sharp 150ms aviation flash at summit
	if top_strobe:
		var flash = 1.0 if fposmod(time_accum, 1.0) < 0.14 else 0.0
		top_strobe.light_energy = flash * 6.0
	
	# Steady gentle pulse at 40m and 80m rungs
	if mid_beacon_1:
		mid_beacon_1.light_energy = 2.0 + sin(time_accum * 4.0) * 0.8
	if mid_beacon_2:
		mid_beacon_2.light_energy = 2.0 + cos(time_accum * 4.0) * 0.8
