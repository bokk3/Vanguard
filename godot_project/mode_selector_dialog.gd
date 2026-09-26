class_name ModeSelectorDialog
extends Control

## ModeSelectorDialog: Operational Theater Selection Terminal for Project Vanguard.
## Prominently prompts the pilot after authentication to select between Solo Sortie vs AI or Online Combat.
## Also allows immediate pairing of a smartphone as Controller 1 and keyboard layout toggling.

signal theater_selected(mode: String) # "SOLO" or "ONLINE"
signal pair_controller1_requested()
signal layout_toggled(is_azerty: bool)
signal switch_pilot_requested()

@onready var solo_btn: Button = %SoloBtn
@onready var online_btn: Button = %OnlineBtn
@onready var pair_phone_btn: Button = %PairPhoneBtn
@onready var layout_toggle_btn: Button = %LayoutToggleBtn
@onready var pilot_tag_label: Label = %PilotTagLabel
@onready var switch_pilot_btn: Button = %SwitchPilotBtn
@onready var fleet_telemetry_label: Label = %FleetTelemetryLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if solo_btn:
		solo_btn.pressed.connect(_on_solo_pressed)
	if online_btn:
		online_btn.pressed.connect(_on_online_pressed)
	if pair_phone_btn:
		pair_phone_btn.pressed.connect(_on_pair_phone_pressed)
	if layout_toggle_btn:
		layout_toggle_btn.pressed.connect(_on_layout_toggle_pressed)
	if switch_pilot_btn:
		switch_pilot_btn.pressed.connect(_on_switch_pilot_pressed)
		
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr:
		if not net_mgr.network_stats_updated.is_connected(_on_network_stats_updated):
			net_mgr.network_stats_updated.connect(_on_network_stats_updated)
		_update_fleet_telemetry(net_mgr.registered_pilots, net_mgr.online_pilots, net_mgr.active_lobbies)

	_update_layout_button_text()

func show_selector() -> void:
	var auth_mgr = get_node_or_null("/root/AuthManager")
	if pilot_tag_label and auth_mgr:
		var cs = auth_mgr.callsign if not auth_mgr.callsign.is_empty() else "VANGUARD-LEAD"
		pilot_tag_label.text = "PILOT IDENTIFIED: %s // %s // %s" % [cs, auth_mgr.rank, auth_mgr.squadron]
		
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr:
		_update_fleet_telemetry(net_mgr.registered_pilots, net_mgr.online_pilots, net_mgr.active_lobbies)

	_update_layout_button_text()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if solo_btn:
		solo_btn.grab_focus()

func _on_network_stats_updated(reg: int, online: int, lobbies: int) -> void:
	_update_fleet_telemetry(reg, online, lobbies)

func _update_fleet_telemetry(_reg: int, online: int, lobbies: int) -> void:
	if fleet_telemetry_label:
		var status_dot = "🟢" if online > 0 else "⚪"
		fleet_telemetry_label.text = "%s FLEET RADAR: %d PILOTS ONLINE // %d COMBAT LOBBIES ACTIVE" % [status_dot, online, lobbies]

func hide_selector() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_solo_pressed() -> void:
	hide_selector()
	theater_selected.emit("SOLO")

func _on_online_pressed() -> void:
	hide_selector()
	theater_selected.emit("ONLINE")

func _on_pair_phone_pressed() -> void:
	pair_controller1_requested.emit()

func _on_switch_pilot_pressed() -> void:
	hide_selector()
	switch_pilot_requested.emit()

func _on_layout_toggle_pressed() -> void:
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg:
		cfg.reset_keybindings_preset(not cfg.is_azerty)
		_update_layout_button_text()
		layout_toggled.emit(cfg.is_azerty)

func _update_layout_button_text() -> void:
	if not layout_toggle_btn:
		return
	var cfg = get_node_or_null("/root/ConfigManager")
	var is_az = cfg.is_azerty if cfg else false
	layout_toggle_btn.text = "⌨ FLIGHT LAYOUT: %s [CLICK TO SWITCH]" % ("AZERTY (ZQSD)" if is_az else "QWERTY (WASD)")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_on_solo_pressed()
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				_on_online_pressed()
				get_viewport().set_input_as_handled()
			KEY_F1:
				_on_layout_toggle_pressed()
				get_viewport().set_input_as_handled()
			KEY_F3:
				_on_pair_phone_pressed()
				get_viewport().set_input_as_handled()
