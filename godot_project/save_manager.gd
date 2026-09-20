extends Node

## SaveManager: Central save game controller for Project Vanguard.
## Handles serialization and restoration of player flight state, telemetry, ordnance,
## and world state in human-readable JSON format at user://saves/vanguard_savegame.json.

signal game_saved(slot_name: String)
signal game_loaded(slot_name: String)
signal save_error(message: String)

const SAVE_DIR = "user://saves"
const DEFAULT_SLOT = "vanguard_savegame"

var should_load_on_start: bool = false
var pending_slot_name: String = DEFAULT_SLOT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_save_dir()

func ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if err != OK:
			print("[!] SaveManager: Failed to create save directory: ", SAVE_DIR)

func get_save_path(slot_name: String = DEFAULT_SLOT) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot_name]

func has_save(slot_name: String = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(get_save_path(slot_name))

func get_save_info(slot_name: String = DEFAULT_SLOT) -> Dictionary:
	if not has_save(slot_name):
		return {}
	
	var file = FileAccess.open(get_save_path(slot_name), FileAccess.READ)
	if not file:
		return {}
	
	var json_str = file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(json_str)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	
	return data

func save_game(slot_name: String = DEFAULT_SLOT) -> bool:
	ensure_save_dir()
	
	var root = get_tree().current_scene
	if not root:
		save_error.emit("No active scene to save.")
		return false
	
	var ship = root.get_node_or_null("Spaceship")
	var telemetry = ship.get_node_or_null("CombatTelemetry") if ship else null
	var drone = root.get_node_or_null("EnemyDroneAlpha")
	
	var save_data = {
		"format_version": 1,
		"game_version": ProjectSettings.get_setting("application/config/version", "0.5.0"),
		"timestamp": Time.get_datetime_string_from_system(true),
		"display_date": Time.get_datetime_string_from_system(false, true).replace("T", " "),
		"profile": {
			"callsign": "VANGUARD-LEAD",
			"squadron": "404th Vanguard Strike Wing",
			"rank": "FLIGHT LIEUTENANT"
		},
		"sortie": {
			"mission_id": "SORTIE_01_RECON_INTERCEPT",
			"mission_title": "Operation Archangel: Low-Orbit Intercept",
			"scene_file": root.scene_file_path if root.scene_file_path != "" else "res://main.tscn"
		},
		"ship": ship.get_save_data() if ship and ship.has_method("get_save_data") else {},
		"telemetry": telemetry.get_save_data() if telemetry and telemetry.has_method("get_save_data") else {},
		"world": {
			"drone_alive": is_instance_valid(drone),
			"drone_state": drone.get_save_data() if is_instance_valid(drone) and drone.has_method("get_save_data") else {}
		}
	}
	
	var path = get_save_path(slot_name)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var err_msg = "Could not open file for writing: %s (Error %d)" % [path, FileAccess.get_open_error()]
		print("[!] SaveManager: ", err_msg)
		save_error.emit(err_msg)
		return false
	
	var pretty_json = JSON.stringify(save_data, "  ")
	file.store_string(pretty_json)
	file.close()
	
	print(">>> Project Vanguard: Sortie state saved successfully to: ", path)
	game_saved.emit(slot_name)
	return true

func load_save_data(slot_name: String = DEFAULT_SLOT) -> Dictionary:
	return get_save_info(slot_name)

func apply_save_to_current_scene(slot_name: String = DEFAULT_SLOT) -> bool:
	var data = load_save_data(slot_name)
	if data.is_empty():
		save_error.emit("Save data is empty or invalid.")
		return false
	
	var root = get_tree().current_scene
	if not root:
		return false
	
	var ship = root.get_node_or_null("Spaceship")
	if ship and data.has("ship") and ship.has_method("restore_save_data"):
		ship.restore_save_data(data["ship"])
	
	var telemetry = ship.get_node_or_null("CombatTelemetry") if ship else null
	if telemetry and data.has("telemetry") and telemetry.has_method("restore_save_data"):
		telemetry.restore_save_data(data["telemetry"])
	
	var drone = root.get_node_or_null("EnemyDroneAlpha")
	if data.has("world"):
		var world_info = data["world"]
		if world_info.has("drone_alive"):
			var drone_alive = bool(world_info["drone_alive"])
			if not drone_alive and is_instance_valid(drone):
				drone.queue_free()
			elif is_instance_valid(drone) and world_info.has("drone_state") and drone.has_method("restore_save_data"):
				drone.restore_save_data(world_info["drone_state"])
	
	print(">>> Project Vanguard: Sortie state restored successfully from: ", get_save_path(slot_name))
	game_loaded.emit(slot_name)
	return true

func delete_save(slot_name: String = DEFAULT_SLOT) -> bool:
	var path = get_save_path(slot_name)
	if FileAccess.file_exists(path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			var err = dir.remove("%s.json" % slot_name)
			return err == OK
	return false
