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
var enable_rumble: bool = true
var radar_circular_default: bool = true

var master_volume: float = 1.0
var sfx_volume: float = 0.85
var music_volume: float = 0.85
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

const P2_ACTIONS = [
	"p2_throttle_up",
	"p2_throttle_down",
	"p2_yaw_left",
	"p2_yaw_right",
	"p2_roll_left",
	"p2_roll_right",
	"p2_pitch_up",
	"p2_pitch_down",
	"p2_boost",
	"p2_fire_gun",
	"p2_fire_missile",
	"p2_toggle_radar"
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
	enable_rumble = _config.get_value("controls", "enable_rumble", true)
	
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
	music_volume = _config.get_value("audio", "music_volume", 0.85)
	
	apply_input_mappings()
	apply_display_and_audio()

func save_settings() -> void:
	_config.set_value("controls", "is_azerty", is_azerty)
	_config.set_value("gameplay", "difficulty", difficulty)
	_config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	_config.set_value("controls", "invert_pitch", invert_pitch)
	_config.set_value("flight", "enable_gravity", enable_gravity)
	_config.set_value("controls", "enable_rumble", enable_rumble)
	
	# Save Keybindings
	for action in keybindings.keys():
		_config.set_value("keybindings", action, keybindings[action])
	
	_config.set_value("display", "radar_circular_default", radar_circular_default)
	_config.set_value("display", "window_mode", window_mode)
	
	_config.set_value("audio", "master_volume", master_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	_config.set_value("audio", "music_volume", music_volume)
	
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
		
		# Bind Cross-Platform Controller Events (Xbox & PlayStation 5 / DualSense via SDL DB)
		_apply_joypad_mappings_for_action(action)
	
	_apply_ui_joypad_mappings()
	_apply_p2_input_mappings()

func _apply_joypad_mappings_for_action(action: String) -> void:
	match action:
		"throttle_up":
			# Right Trigger RT / R2 (analog acceleration)
			var m_rt = InputEventJoypadMotion.new()
			m_rt.axis = JOY_AXIS_TRIGGER_RIGHT
			m_rt.axis_value = 1.0
			InputMap.action_add_event(action, m_rt)
			var b_up = InputEventJoypadButton.new()
			b_up.button_index = JOY_BUTTON_DPAD_UP
			InputMap.action_add_event(action, b_up)
			
		"throttle_down":
			# Left Trigger LT / L2 (analog airbrakes)
			var m_lt = InputEventJoypadMotion.new()
			m_lt.axis = JOY_AXIS_TRIGGER_LEFT
			m_lt.axis_value = 1.0
			InputMap.action_add_event(action, m_lt)
			var b_dn = InputEventJoypadButton.new()
			b_dn.button_index = JOY_BUTTON_DPAD_DOWN
			InputMap.action_add_event(action, b_dn)
			
		"pitch_up":
			# Left Stick Down (+Y) pulls elevator UP
			var m_pu = InputEventJoypadMotion.new()
			m_pu.axis = JOY_AXIS_LEFT_Y
			m_pu.axis_value = 1.0
			InputMap.action_add_event(action, m_pu)
			var b_pu = InputEventJoypadButton.new()
			b_pu.button_index = JOY_BUTTON_DPAD_DOWN
			InputMap.action_add_event(action, b_pu)
			
		"pitch_down":
			# Left Stick Up (-Y) pushes elevator DOWN
			var m_pd = InputEventJoypadMotion.new()
			m_pd.axis = JOY_AXIS_LEFT_Y
			m_pd.axis_value = -1.0
			InputMap.action_add_event(action, m_pd)
			var b_pd = InputEventJoypadButton.new()
			b_pd.button_index = JOY_BUTTON_DPAD_UP
			InputMap.action_add_event(action, b_pd)
			
		"roll_left":
			# Left Stick Left (-X) banks LEFT
			var m_rl = InputEventJoypadMotion.new()
			m_rl.axis = JOY_AXIS_LEFT_X
			m_rl.axis_value = -1.0
			InputMap.action_add_event(action, m_rl)
			var b_rl = InputEventJoypadButton.new()
			b_rl.button_index = JOY_BUTTON_DPAD_LEFT
			InputMap.action_add_event(action, b_rl)
			
		"roll_right":
			# Left Stick Right (+X) banks RIGHT
			var m_rr = InputEventJoypadMotion.new()
			m_rr.axis = JOY_AXIS_LEFT_X
			m_rr.axis_value = 1.0
			InputMap.action_add_event(action, m_rr)
			var b_rr = InputEventJoypadButton.new()
			b_rr.button_index = JOY_BUTTON_DPAD_RIGHT
			InputMap.action_add_event(action, b_rr)
			
		"yaw_left":
			# Left Bumper LB / L1
			var b_yl = InputEventJoypadButton.new()
			b_yl.button_index = JOY_BUTTON_LEFT_SHOULDER
			InputMap.action_add_event(action, b_yl)
			# Alternate: Right Stick Left (-X)
			var m_yl = InputEventJoypadMotion.new()
			m_yl.axis = JOY_AXIS_RIGHT_X
			m_yl.axis_value = -1.0
			InputMap.action_add_event(action, m_yl)
			
		"yaw_right":
			# Right Bumper RB / R1
			var b_yr = InputEventJoypadButton.new()
			b_yr.button_index = JOY_BUTTON_RIGHT_SHOULDER
			InputMap.action_add_event(action, b_yr)
			# Alternate: Right Stick Right (+X)
			var m_yr = InputEventJoypadMotion.new()
			m_yr.axis = JOY_AXIS_RIGHT_X
			m_yr.axis_value = 1.0
			InputMap.action_add_event(action, m_yr)
			
		"boost":
			# Left Stick Click (L3)
			var b_l3 = InputEventJoypadButton.new()
			b_l3.button_index = JOY_BUTTON_LEFT_STICK
			InputMap.action_add_event(action, b_l3)
			# Alternate: Button Y (Xbox Y / PS Triangle)
			var b_y = InputEventJoypadButton.new()
			b_y.button_index = JOY_BUTTON_Y
			InputMap.action_add_event(action, b_y)
			
		"fire_gun":
			# Button A (Xbox A / PS Cross)
			var b_a = InputEventJoypadButton.new()
			b_a.button_index = JOY_BUTTON_A
			InputMap.action_add_event(action, b_a)
			# Alternate: Right Stick Click (R3)
			var b_r3 = InputEventJoypadButton.new()
			b_r3.button_index = JOY_BUTTON_RIGHT_STICK
			InputMap.action_add_event(action, b_r3)
			
		"fire_missile":
			# Button B (Xbox B / PS Circle)
			var b_b = InputEventJoypadButton.new()
			b_b.button_index = JOY_BUTTON_B
			InputMap.action_add_event(action, b_b)
			
		"toggle_radar":
			# Button X (Xbox X / PS Square)
			var b_x = InputEventJoypadButton.new()
			b_x.button_index = JOY_BUTTON_X
			InputMap.action_add_event(action, b_x)

func _apply_ui_joypad_mappings() -> void:
	# ui_accept: add Button A (Xbox A / PS Cross)
	if InputMap.has_action("ui_accept"):
		var has_a = false
		for ev in InputMap.action_get_events("ui_accept"):
			if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_A:
				has_a = true
				break
		if not has_a:
			var ev_a = InputEventJoypadButton.new()
			ev_a.button_index = JOY_BUTTON_A
			InputMap.action_add_event("ui_accept", ev_a)
	
	# ui_cancel: add Button B (Xbox B / PS Circle)
	if InputMap.has_action("ui_cancel"):
		var has_b = false
		for ev in InputMap.action_get_events("ui_cancel"):
			if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_B:
				has_b = true
				break
		if not has_b:
			var ev_b = InputEventJoypadButton.new()
			ev_b.button_index = JOY_BUTTON_B
			InputMap.action_add_event("ui_cancel", ev_b)

func _apply_p2_input_mappings() -> void:
	for action in P2_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)
	
	# Default Player 2 Keyboard Bindings (IJKL cluster + NumPad)
	var p2_keys = {
		"p2_throttle_up": [KEY_Y, KEY_KP_8],
		"p2_throttle_down": [KEY_H, KEY_KP_5],
		"p2_pitch_up": [KEY_K, KEY_KP_2],
		"p2_pitch_down": [KEY_I],
		"p2_roll_left": [KEY_J, KEY_KP_4],
		"p2_roll_right": [KEY_L, KEY_KP_6],
		"p2_yaw_left": [KEY_U, KEY_KP_7],
		"p2_yaw_right": [KEY_O, KEY_KP_9],
		"p2_boost": [KEY_N, KEY_KP_0],
		"p2_fire_gun": [KEY_ENTER, KEY_KP_ENTER],
		"p2_fire_missile": [KEY_M, KEY_KP_PERIOD],
		"p2_toggle_radar": [KEY_P]
	}
	
	for act in p2_keys:
		for k in p2_keys[act]:
			var ev = InputEventKey.new()
			ev.keycode = k
			InputMap.action_add_event(act, ev)
	
	# Default Gamepad Mappings for Player 2 (Joypad device 1, with device 0 fallback when P1 is on keyboard)
	_apply_p2_joypad_mappings()

func _apply_p2_joypad_mappings() -> void:
	# Bind Gamepad actions for device 1 (Second Controller)
	var joy_axes = {
		"p2_throttle_up": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
		"p2_throttle_down": [JOY_AXIS_TRIGGER_LEFT, 1.0],
		"p2_pitch_up": [JOY_AXIS_LEFT_Y, 1.0],
		"p2_pitch_down": [JOY_AXIS_LEFT_Y, -1.0],
		"p2_roll_left": [JOY_AXIS_LEFT_X, -1.0],
		"p2_roll_right": [JOY_AXIS_LEFT_X, 1.0],
		"p2_yaw_left": [JOY_AXIS_RIGHT_X, -1.0],
		"p2_yaw_right": [JOY_AXIS_RIGHT_X, 1.0]
	}
	
	for act in joy_axes:
		var cfg = joy_axes[act]
		# Device 1
		var m1 = InputEventJoypadMotion.new()
		m1.device = 1
		m1.axis = cfg[0]
		m1.axis_value = cfg[1]
		InputMap.action_add_event(act, m1)
	
	var joy_buttons = {
		"p2_throttle_up": [JOY_BUTTON_DPAD_UP],
		"p2_throttle_down": [JOY_BUTTON_DPAD_DOWN],
		"p2_pitch_up": [JOY_BUTTON_DPAD_DOWN],
		"p2_pitch_down": [JOY_BUTTON_DPAD_UP],
		"p2_yaw_left": [JOY_BUTTON_LEFT_SHOULDER],
		"p2_yaw_right": [JOY_BUTTON_RIGHT_SHOULDER],
		"p2_boost": [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_Y],
		"p2_fire_gun": [JOY_BUTTON_A, JOY_BUTTON_RIGHT_STICK],
		"p2_fire_missile": [JOY_BUTTON_B],
		"p2_toggle_radar": [JOY_BUTTON_X]
	}
	
	for act in joy_buttons:
		for btn in joy_buttons[act]:
			var b1 = InputEventJoypadButton.new()
			b1.device = 1
			b1.button_index = btn
			InputMap.action_add_event(act, b1)

func play_rumble(weak: float, strong: float, duration: float, device: int = 0) -> void:
	if enable_rumble and Input.get_connected_joypads().size() > 0:
		Input.start_joy_vibration(device, clamp(weak, 0.0, 1.0), clamp(strong, 0.0, 1.0), duration)

func get_connected_controller_name(device: int = 0) -> String:
	var joypads = Input.get_connected_joypads()
	if joypads.has(device):
		return Input.get_joy_name(device)
	elif joypads.size() > 0:
		return Input.get_joy_name(joypads[0])
	return "No Controller Detected (Plug in Xbox / PS5 via USB or Bluetooth)"

const JOYPAD_CONTROLS_TABLE = [
	{"action": "Pitch Up / Down", "xbox": "Left Stick Up / Down (Pull to climb)", "ps": "Left Stick Up / Down (Pull to climb)"},
	{"action": "Roll (Bank Left / Right)", "xbox": "Left Stick Left / Right", "ps": "Left Stick Left / Right"},
	{"action": "Yaw (Rudders Left / Right)", "xbox": "LB / RB (Bumpers) or Right Stick", "ps": "L1 / R1 (Bumpers) or Right Stick"},
	{"action": "Throttle / Accelerate", "xbox": "RT (Right Trigger)", "ps": "R2 (Right Trigger)"},
	{"action": "Airbrakes / Decelerate", "xbox": "LT (Left Trigger)", "ps": "L2 (Left Trigger)"},
	{"action": "Afterburner Nitro (Boost)", "xbox": "L3 (Click Left Stick) or Y", "ps": "L3 (Click Left Stick) or △ (Triangle)"},
	{"action": "Rotary Machine Gun (BRRR)", "xbox": "A Button or R3 (Click Right Stick)", "ps": "✕ (Cross) or R3 (Click Right Stick)"},
	{"action": "Strike Missile", "xbox": "B Button", "ps": "○ (Circle)"},
	{"action": "Radar Display Mode", "xbox": "X Button", "ps": "▢ (Square)"},
	{"action": "Pause / In-Flight Menu", "xbox": "Menu / Start Button", "ps": "Options Button"}
]

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

func reset_to_factory_defaults() -> void:
	is_azerty = detect_system_azerty()
	difficulty = "NORMAL"
	mouse_sensitivity = 1.0
	invert_pitch = false
	enable_gravity = true
	enable_rumble = true
	radar_circular_default = true
	
	master_volume = 1.0
	sfx_volume = 0.85
	music_volume = 0.85
	window_mode = 0
	
	keybindings = get_default_keybindings(is_azerty)
	
	if FileAccess.file_exists(CONFIG_PATH):
		DirAccess.remove_absolute(CONFIG_PATH)
	save_settings()
	
	apply_input_mappings()
	apply_display_and_audio()
	settings_changed.emit()
	keybindings_updated.emit()
	print(">>> [ConfigManager] Factory settings restored to defaults.")

func get_difficulty_damage_multiplier() -> float:
	match difficulty.to_upper():
		"EASY": return 0.5
		"ACE", "HARD": return 1.5
		_: return 1.0

func get_difficulty_drone_cooldown() -> float:
	match difficulty.to_upper():
		"EASY": return 5.5
		"ACE", "HARD": return 2.4
		_: return 3.8

func get_difficulty_drone_spread() -> float:
	match difficulty.to_upper():
		"EASY": return 0.14
		"ACE", "HARD": return 0.035
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
	
	# Apply Audio Bus Volumes if buses exist
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		var db = linear_to_db(clamp(master_volume, 0.0001, 1.0))
		AudioServer.set_bus_volume_db(master_idx, db)
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		var sfx_db = linear_to_db(clamp(sfx_volume, 0.0001, 1.0))
		AudioServer.set_bus_volume_db(sfx_idx, sfx_db)
	var ui_idx = AudioServer.get_bus_index("UI")
	if ui_idx >= 0:
		var ui_db = linear_to_db(clamp(sfx_volume, 0.0001, 1.0))
		AudioServer.set_bus_volume_db(ui_idx, ui_db)
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		var music_db = linear_to_db(clamp(music_volume, 0.0001, 1.0))
		AudioServer.set_bus_volume_db(music_idx, music_db)

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
