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
	
	var mm = get_node_or_null("/root/MissionManager")
	var campaign_info = mm.get_save_data() if mm and mm.has_method("get_save_data") else {}
	var cur_mission_id = mm.current_mission_id if mm else "M01"
	var cur_mission_data = mm.get_mission(cur_mission_id) if mm else {}
	
	var auth_mgr = get_node_or_null("/root/AuthManager")
	var pilot_profile = {
		"callsign": auth_mgr.callsign if (auth_mgr and not auth_mgr.callsign.is_empty()) else "VANGUARD-LEAD",
		"squadron": auth_mgr.squadron if auth_mgr else "404th Vanguard Strike Wing",
		"rank": auth_mgr.rank if auth_mgr else "LIEUTENANT"
	}

	var save_data = {
		"format_version": 1,
		"game_version": ProjectSettings.get_setting("application/config/version", "0.8.0"),
		"timestamp": Time.get_datetime_string_from_system(true),
		"display_date": Time.get_datetime_string_from_system(false, true).replace("T", " "),
		"profile": pilot_profile,
		"sortie": {
			"mission_id": cur_mission_id,
			"mission_title": cur_mission_data.get("codename", "Operation CLOUDBURST"),
			"theater": cur_mission_data.get("theater", "Sub-Cloud Interception Sector 07"),
			"scene_file": root.scene_file_path if root.scene_file_path != "" else "res://main.tscn"
		},
		"campaign": campaign_info,
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
	
	if data.has("campaign"):
		var mm = get_node_or_null("/root/MissionManager")
		if mm and mm.has_method("restore_save_data"):
			mm.restore_save_data(data["campaign"])
	
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

func delete_all_saves(mm_override: Node = null) -> bool:
	should_load_on_start = false
	var success = true
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".json"):
					var err = dir.remove(file_name)
					if err != OK:
						success = false
				file_name = dir.get_next()
			dir.list_dir_end()
	
	# Also reset campaign progression in MissionManager if present
	var mm = _get_mission_manager(mm_override)
	if mm and mm.has_method("reset_campaign_progress"):
		mm.reset_campaign_progress()
		
	print(">>> [SaveManager] All saved sortie states deleted.")
	return success

func _get_mission_manager(override: Node = null) -> Node:
	if override:
		return override
	if is_inside_tree() and get_tree() and get_tree().root:
		var m = get_tree().root.get_node_or_null("MissionManager")
		if m: return m
	if get_parent():
		var m = get_parent().get_node_or_null("MissionManager")
		if m: return m
	var main_loop = Engine.get_main_loop() as SceneTree
	if main_loop and main_loop.root:
		var m = main_loop.root.get_node_or_null("MissionManager")
		if m: return m
	return null

