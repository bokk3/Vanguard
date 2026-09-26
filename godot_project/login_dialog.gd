class_name LoginDialog
extends Control

## LoginDialog: In-game sci-fi military authentication terminal for Project Vanguard.
## Prompts pilot for callsign, squadron, and optional cloud access credentials.

signal login_completed(profile: Dictionary)

@onready var callsign_input: LineEdit = %CallsignInput
@onready var squadron_option: OptionButton = %SquadronOption
@onready var password_input: LineEdit = %PasswordInput
@onready var remember_check: CheckBox = %RememberCheck
@onready var auth_btn: Button = %AuthBtn
@onready var quick_btn: Button = %QuickBtn
@onready var cloud_toggle_btn: Button = %CloudToggleBtn
@onready var status_label: Label = %StatusLabel
@onready var password_container: VBoxContainer = %PasswordContainer
@onready var cloud_help_label: Label = %CloudHelpLabel

@onready var close_btn: Button = %CloseBtn
@onready var register_toggle_btn: Button = %RegisterToggleBtn

var is_cloud_mode: bool = false
var is_register_mode: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_populate_squadrons()
	
	if close_btn and not close_btn.pressed.is_connected(hide):
		close_btn.pressed.connect(hide)
	if auth_btn and not auth_btn.pressed.is_connected(_on_auth_pressed):
		auth_btn.pressed.connect(_on_auth_pressed)
	if quick_btn and not quick_btn.pressed.is_connected(_on_quick_pressed):
		quick_btn.pressed.connect(_on_quick_pressed)
	if cloud_toggle_btn and not cloud_toggle_btn.pressed.is_connected(_on_toggle_cloud_mode):
		cloud_toggle_btn.pressed.connect(_on_toggle_cloud_mode)
	if register_toggle_btn and not register_toggle_btn.pressed.is_connected(_on_toggle_register_mode):
		register_toggle_btn.pressed.connect(_on_toggle_register_mode)
	if callsign_input and not callsign_input.text_submitted.is_connected(_on_input_submitted):
		callsign_input.text_submitted.connect(_on_input_submitted)
	if password_input and not password_input.text_submitted.is_connected(_on_input_submitted):
		password_input.text_submitted.connect(_on_input_submitted)
		
	var auth_mgr = get_node_or_null("/root/AuthManager")
	if auth_mgr:
		if not auth_mgr.auth_success.is_connected(_on_auth_success):
			auth_mgr.auth_success.connect(_on_auth_success)
		if not auth_mgr.auth_failed.is_connected(_on_auth_failed):
			auth_mgr.auth_failed.connect(_on_auth_failed)
			
	_update_mode_ui()
	
	# Pre-fill with last known callsign or default
	if auth_mgr and not auth_mgr.callsign.is_empty():
		callsign_input.text = auth_mgr.callsign
	else:
		callsign_input.text = "MAVERICK"
	callsign_input.grab_focus()
	callsign_input.select_all()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_auth_pressed()
		get_viewport().set_input_as_handled()

func _on_input_submitted(_text: String) -> void:
	_on_auth_pressed()

func _populate_squadrons() -> void:
	if not squadron_option:
		return
	squadron_option.clear()
	squadron_option.add_item("404th Vanguard Strike Wing")
	squadron_option.add_item("Aegis Fleet Defense Interceptors")
	squadron_option.add_item("Helion Orbital Reconnaissance")
	squadron_option.add_item("Solaris Deep-Space Division")

func _update_mode_ui() -> void:
	if is_cloud_mode:
		if password_container: password_container.show()
		if cloud_help_label: cloud_help_label.show()
		if cloud_toggle_btn: cloud_toggle_btn.text = "📂 LOCAL DOSSIER"
		if is_register_mode:
			if register_toggle_btn: register_toggle_btn.text = "🔑 LOGIN EXISTING"
			if auth_btn: auth_btn.text = "📝 REGISTER & COMMISSION PILOT"
			if status_label:
				status_label.text = "// MODE: CREATE NEW PILOT ACCOUNT ON CLOUD //"
				status_label.modulate = Color(1.0, 0.85, 0.2)
		else:
			if register_toggle_btn: register_toggle_btn.text = "📝 CLOUD REGISTER"
			if auth_btn: auth_btn.text = "🌐 VERIFY CLOUD CREDENTIALS"
			if status_label:
				status_label.text = "// MODE: VANGUARD CLOUD NETWORK (ONLINE DB) //"
				status_label.modulate = Color(0.2, 0.85, 1.0)
	else:
		if password_container: password_container.hide()
		if cloud_help_label: cloud_help_label.hide()
		if cloud_toggle_btn: cloud_toggle_btn.text = "🌐 CLOUD LOGIN"
		if register_toggle_btn: register_toggle_btn.text = "📝 CLOUD REGISTER"
		if auth_btn: auth_btn.text = "🚀 COMMENCE LOCAL SORTIE"
		if status_label:
			status_label.text = "// MODE: LOCAL FLIGHT LOG (OFFLINE READY) //"
			status_label.modulate = Color(0.1, 0.95, 0.4)

func _on_toggle_cloud_mode() -> void:
	if not is_cloud_mode:
		is_cloud_mode = true
		is_register_mode = false
	else:
		is_cloud_mode = false
		is_register_mode = false
	_update_mode_ui()

func _on_toggle_register_mode() -> void:
	if not is_cloud_mode:
		is_cloud_mode = true
		is_register_mode = true
	else:
		is_register_mode = not is_register_mode
	_update_mode_ui()

func _on_auth_pressed() -> void:
	var cs = callsign_input.text.strip_edges().to_upper()
	if cs.is_empty():
		status_label.text = "⚠ CALLSIGN CANNOT BE EMPTY"
		status_label.modulate = Color(1.0, 0.3, 0.3)
		callsign_input.grab_focus()
		return
		
	var sq = squadron_option.get_item_text(squadron_option.selected) if squadron_option else "404th Vanguard Strike Wing"
	var rem = remember_check.button_pressed if remember_check else true
	
	status_label.text = "VERIFYING BIOMETRICS & SQUADRON ROSTER..."
	status_label.modulate = Color(1.0, 0.8, 0.2)
	
	var auth_mgr = get_node_or_null("/root/AuthManager")
	if not auth_mgr:
		hide()
		login_completed.emit({ "callsign": cs, "rank": "LIEUTENANT", "squadron": sq })
		return
		
	if is_cloud_mode:
		var pwd = password_input.text if password_input else ""
		if is_register_mode:
			var default_email = cs.to_lower().replace(" ", "_") + "@vanguard.fleet"
			auth_mgr.register_cloud(cs, default_email, pwd, sq, rem)
		else:
			auth_mgr.login_cloud(cs, pwd, rem)
	else:
		auth_mgr.login_local(cs, sq, rem)

func _on_quick_pressed() -> void:
	var auth_mgr = get_node_or_null("/root/AuthManager")
	if auth_mgr:
		status_label.text = "SCRAMBLING GUEST CALLSIGN..."
		status_label.modulate = Color(0.0, 0.9, 1.0)
		auth_mgr.quick_sortie()
	else:
		hide()
		login_completed.emit({ "callsign": "VIPER-1", "rank": "CADET", "squadron": "404th Vanguard Strike Wing" })

func _on_auth_success(profile: Dictionary) -> void:
	if status_label:
		status_label.text = "CLEARANCE GRANTED // WELCOME, %s %s" % [profile.get("rank", "PILOT"), profile.get("callsign", "")]
		status_label.modulate = Color(0.0, 0.95, 0.4)
	
	# Brief delay for dramatic confirmation
	await get_tree().create_timer(0.3).timeout
	hide()
	login_completed.emit(profile)

func _on_auth_failed(reason: String) -> void:
	if status_label:
		status_label.text = "ACCESS DENIED: %s" % reason.to_upper()
		status_label.modulate = Color(1.0, 0.2, 0.3)
