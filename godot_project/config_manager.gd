extends Node

## ConfigManager: Centralized settings persistence for Project Vanguard.
## Handles avionics, controls, audio, and visual preferences stored in user://settings.cfg.

signal settings_changed

const CONFIG_PATH = "user://settings.cfg"

# Config Properties with sensible defaults
var is_azerty: bool = false
var mouse_sensitivity: float = 1.0
var invert_pitch: bool = false
var enable_gravity: bool = true
var radar_circular_default: bool = true

var master_volume: float = 1.0
var sfx_volume: float = 0.85
var window_mode: int = 0  # 0: Windowed, 1: Fullscreen, 2: Borderless

var _config: ConfigFile = ConfigFile.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

func load_settings() -> void:
	var err = _config.load(CONFIG_PATH)
	if err != OK:
		# First launch: auto-detect keyboard layout based on OS
		is_azerty = detect_system_azerty()
		save_settings()
		return
	
	# Controls & Avionics
	is_azerty = _config.get_value("controls", "is_azerty", detect_system_azerty())
	mouse_sensitivity = _config.get_value("controls", "mouse_sensitivity", 1.0)
	invert_pitch = _config.get_value("controls", "invert_pitch", false)
	enable_gravity = _config.get_value("flight", "enable_gravity", true)
	
	# Display & HUD
	radar_circular_default = _config.get_value("display", "radar_circular_default", true)
	window_mode = _config.get_value("display", "window_mode", 0)
	
	# Audio
	master_volume = _config.get_value("audio", "master_volume", 1.0)
	sfx_volume = _config.get_value("audio", "sfx_volume", 0.85)
	
	apply_display_and_audio()

func save_settings() -> void:
	_config.set_value("controls", "is_azerty", is_azerty)
	_config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	_config.set_value("controls", "invert_pitch", invert_pitch)
	_config.set_value("flight", "enable_gravity", enable_gravity)
	
	_config.set_value("display", "radar_circular_default", radar_circular_default)
	_config.set_value("display", "window_mode", window_mode)
	
	_config.set_value("audio", "master_volume", master_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	
	_config.save(CONFIG_PATH)
	apply_display_and_audio()
	settings_changed.emit()

func apply_display_and_audio() -> void:
	# Apply Window Mode
	match window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	
	# Apply Audio Bus Volumes if master bus exists
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		var db = linear_to_db(clamp(master_volume, 0.0001, 1.0))
		AudioServer.set_bus_volume_db(master_idx, db)

func detect_system_azerty() -> bool:
	if OS.get_name() == "Windows":
		var out_locale: Array = []
		var err = OS.execute("reg", ["query", "HKCU\\Control Panel\\International", "/v", "LocaleName"], out_locale)
		if err == 0 and out_locale.size() > 0:
			var loc_str = str(out_locale[0]).to_upper()
			if "-BE" in loc_str or "-FR" in loc_str:
				return true
		
		var out_preload: Array = []
		err = OS.execute("reg", ["query", "HKCU\\Keyboard Layout\\Preload"], out_preload)
		if err == 0 and out_preload.size() > 0:
			var txt = str(out_preload[0]).to_lower()
			if "080c" in txt or "0813" in txt or "040c" in txt:
				return true

	var layout_idx = DisplayServer.keyboard_get_current_layout()
	if layout_idx >= 0:
		var layout_name = DisplayServer.keyboard_get_layout_name(layout_idx).to_lower()
		if "azerty" in layout_name or "belgian" in layout_name or "french" in layout_name:
			return true

	var locale = OS.get_locale().to_lower()
	if locale.ends_with("_be") or locale.begins_with("fr_") or locale == "fr":
		return true

	return false
