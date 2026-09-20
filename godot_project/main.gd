extends Node3D

## Main: Level scene controller for Project Vanguard.
## Coordinates scene setup with MissionManager autoload on initialization.

func _ready() -> void:
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("initialize_level"):
		mm.initialize_level(self)
