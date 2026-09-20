extends Node

## ConfigManager: Centralized settings persistence & InputMap manager for Project Vanguard.
## Handles avionics, customizable keybindings, audio, and display preferences in user://settings.cfg.

signal settings_changed
signal keybindings_updated

const CONFIG_PATH = "user://settings.cfg"

# Config Properties
var is_azerty: bool = false
var difficulty: String = "NORMAL" # "EASY", "NORMAL", "ACE"
var mouse_sensitivity: float = 1.0
var invert_pitch: bool = false
var enable_gravity: bool = true
var radar_circular_default: bool = true

var master_volume: float = 1.0
var sfx_volume: float = 0.85
var window_mode: int = 0  # 0: Windowed, 1: Fullscreen, 2: Borderless

# Action metadata
const ACTIONS = [
	"throttle_up",
	"throttle_down",
	"yaw_left",
	"yaw_right",
	"roll_left",
	"roll_right",
	"pitch_up",
	"pitch_down",
	"boost",
	"fire_gun",
	"fire_missile",
	"toggle_radar"
]

const ACTION_LABELS = {
	"throttle_up": "Throttle Forward",
	"throttle_down": "Brake / Reverse",
	"yaw_left": "Turn Left (Yaw)",
	"yaw_right": "Turn Right (Yaw)",
	"roll_left": "Roll Left (Bank)",
	"roll_right": "Roll Right (Bank)",
	"pitch_up": "Pitch Up (Elevator)",
	"pitch_down": "Pitch Down (Elevator)",
	"boost": "Afterburner Nitro",
	"fire_gun": "Rotary Machine Gun (BRRR)",
	"fire_missile": "Launch Strike Missile",
	"toggle_radar": "Toggle Radar Display"
}

# Runtime keybinding dictionary: action -> primary keycode (int)
var keybindings: Dictionary = {}

var _config: ConfigFile = ConfigFile.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

func get_default_keybindings(azerty: bool) -> Dictionary:
	if azerty:
		return {
			"throttle_up": KEY_Z,
			"throttle_down": KEY_S,
			"yaw_left": KEY_LEFT,
			"yaw_right": KEY_RIGHT,
			"roll_left": KEY_Q,
			"roll_right": KEY_D,
			"pitch_up": KEY_UP,
			"pitch_down": KEY_DOWN,
			"boost": KEY_SHIFT,
			"fire_gun": KEY_F,
			"fire_missile": KEY_SPACE,
			"toggle_radar": KEY_R
		}
	else:
		return {
			"throttle_up": KEY_W,
			"throttle_down": KEY_S,
			"yaw_left": KEY_LEFT,
			"yaw_right": KEY_RIGHT,
			"roll_left": KEY_A,
			"roll_right": KEY_D,
			"pitch_up": KEY_UP,
			"pitch_down": KEY_DOWN,
			"boost": KEY_SHIFT,
			"fire_gun": KEY_F,
			"fire_missile": KEY_SPACE,
			"toggle_radar": KEY_R
		}

# Additional secondary/alternate keys always bound for convenience (non-conflicting)
func get_alternate_keys(action: String, _azerty: bool) -> Array:
	match action:
		"fire_missile":
			return [KEY_ENTER]
		_:
			return []

func load_settings() -> void:
	var err = _config.load(CONFIG_PATH)
	if err != OK:
		# First launch: auto-detect keyboard layout based on OS
		is_azerty = detect_system_azerty()
		keybindings = get_default_keybindings(is_azerty)
		apply_input_mappings()
		save_settings()
		return
	
	# Controls & Avionics
	is_azerty = _config.get_value("controls", "is_azerty", detect_system_azerty())
	difficulty = _config.get_value("gameplay", "difficulty", "NORMAL")
	mouse_sensitivity = _config.get_value("controls", "mouse_sensitivity", 1.0)
	invert_pitch = _config.get_value("controls", "invert_pitch", false)
	enable_gravity = _config.get_value("flight", "enable_gravity", true)
	
	# Keybindings
	var defaults = get_default_keybindings(is_azerty)
	for action in ACTIONS:
		var saved_code = _config.get_value("keybindings", action, defaults.get(action, KEY_NONE))
		keybindings[action] = int(saved_code)
	
	# Display & HUD
	radar_circular_default = _config.get_value("display", "radar_circular_default", true)
	window_mode = _config.get_value("display", "window_mode", 0)
	
	# Audio
	master_volume = _config.get_value("audio", "master_volume", 1.0)
	sfx_volume = _config.get_value("audio", "sfx_volume", 0.85)
	
	apply_input_mappings()
	apply_display_and_audio()

func save_settings() -> void:
	_config.set_value("controls", "is_azerty", is_azerty)
	_config.set_value("gameplay", "difficulty", difficulty)
	_config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	_config.set_value("controls", "invert_pitch", invert_pitch)
	_config.set_value("flight", "enable_gravity", enable_gravity)
	
	# Save Keybindings
	for action in keybindings.keys():
		_config.set_value("keybindings", action, keybindings[action])
	
	_config.set_value("display", "radar_circular_default", radar_circular_default)
	_config.set_value("display", "window_mode", window_mode)
	
	_config.set_value("audio", "master_volume", master_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	
	_config.save(CONFIG_PATH)
	apply_input_mappings()
	apply_display_and_audio()
	settings_changed.emit()
	keybindings_updated.emit()

func apply_input_mappings() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)
		
		# Bind Primary Key (logical keycode only, respecting user layout)
		var primary_code = keybindings.get(action, KEY_NONE)
		if primary_code != KEY_NONE:
			var ev = InputEventKey.new()
			ev.keycode = primary_code
			InputMap.action_add_event(action, ev)
		
		# Bind Alternate/Secondary Keys for convenience (e.g. Enter for missile)
		var alternates = get_alternate_keys(action, is_azerty)
		for alt_code in alternates:
			if alt_code != primary_code:
				var ev_alt = InputEventKey.new()
				ev_alt.keycode = alt_code
				InputMap.action_add_event(action, ev_alt)
		
		# Bind Combat Mouse Controls: Left Click = Machine Gun (BRRR), Right Click = Missiles
		if action == "fire_gun":
			var ev_m = InputEventMouseButton.new()
			ev_m.button_index = MOUSE_BUTTON_LEFT
			InputMap.action_add_event(action, ev_m)
		elif action == "fire_missile":
			var ev_m = InputEventMouseButton.new()
			ev_m.button_index = MOUSE_BUTTON_RIGHT
			InputMap.action_add_event(action, ev_m)

func rebind_action(action: String, new_keycode: int) -> void:
	if not ACTIONS.has(action):
		return
	keybindings[action] = new_keycode
	apply_input_mappings()
	save_settings()

func reset_keybindings_preset(azerty: bool) -> void:
	is_azerty = azerty
	keybindings = get_default_keybindings(azerty)
	apply_input_mappings()
	save_settings()

func get_difficulty_damage_multiplier() -> float:
	match difficulty.to_upper():
		"EASY": return 0.5
		"ACE", "HARD": return 1.5
		_: return 1.0

func get_difficulty_drone_cooldown() -> float:
	match difficulty.to_upper():
		"EASY": return 4.5
		"ACE", "HARD": return 2.0
		_: return 3.0

func get_difficulty_drone_spread() -> float:
	match difficulty.to_upper():
		"EASY": return 0.12
		"ACE", "HARD": return 0.04
		_: return 0.08

func get_key_string_for_action(action: String) -> String:
	var code = keybindings.get(action, KEY_NONE)
	if code == KEY_NONE:
		return "UNBOUND"
	var s = OS.get_keycode_string(code)
	return s if s != "" else str(code)

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
