extends Node

## AuthManager: Centralized Pilot Authentication & Identity Controller for Project Vanguard.
## Manages local pilot dossiers, Cloudflare D1 cloud authentication, session tokens,
## and cross-subsystem synchronization (Saves, Multiplayer PvP, Mobile Web HOTAS).

signal auth_success(profile: Dictionary)
signal auth_failed(reason: String)
signal logged_out()
signal email_verification_required(email: String)
signal email_verified_success()
signal email_verification_failed(reason: String)
signal verification_code_resent()

const SAVE_PATH = "user://pilot_profile.json"
const CLOUD_API_BASE = "https://project-vanguard.pages.dev/api/auth"

var is_authenticated: bool = false
var callsign: String = ""
var rank: String = "FLIGHT CADET"
var squadron: String = "404th Vanguard Strike Wing"
var token: String = ""
var pilot_id: String = ""
var email: String = ""
var is_email_verified: bool = false
var remember_me: bool = true
var stats: Dictionary = {
	"total_sorties": 0,
	"total_kills": 0,
	"total_flight_time_sec": 0,
	"highest_mission_unlocked": "M01",
	"battles_won": 0,
	"battles_lost": 0,
	"dogfight_kills": 0,
	"preferred_controls": "AZERTY",
	"battle_history": []
}

var http_request: HTTPRequest = null
var pending_action: String = "" # "login", "register", "verify_code", "resend_code"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	http_request = HTTPRequest.new()
	http_request.timeout = 8.0
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	
	_load_saved_profile()

## Returns a copy of the active pilot profile dictionary
func get_active_profile() -> Dictionary:
	return {
		"callsign": callsign,
		"rank": rank,
		"squadron": squadron,
		"token": token,
		"pilot_id": pilot_id,
		"email": email,
		"is_email_verified": is_email_verified,
		"is_authenticated": is_authenticated,
		"stats": stats.duplicate()
	}

## Loads remembered pilot profile from user://pilot_profile.json
func _load_saved_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
		
	var content = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
		
	var data: Dictionary = parsed
	if not data.get("remember_me", false):
		return
		
	callsign = data.get("callsign", "VANGUARD-LEAD")
	rank = data.get("rank", "LIEUTENANT")
	squadron = data.get("squadron", "404th Vanguard Strike Wing")
	token = data.get("token", "")
	pilot_id = data.get("pilot_id", "")
	email = data.get("email", "")
	is_email_verified = data.get("is_email_verified", false)
	remember_me = true
	if data.has("stats") and typeof(data["stats"]) == TYPE_DICTIONARY:
		stats = data["stats"]
		
	if data.has("rewards") and typeof(data["rewards"]) == TYPE_DICTIONARY:
		var rm = get_node_or_null("/root/RewardManager")
		if rm and rm.has_method("load_save_data"):
			rm.load_save_data(data["rewards"])
		
	is_authenticated = true
	print("[AuthManager] Restored remembered pilot profile: %s [%s] (%s)" % [callsign, rank, squadron])
	_sync_pilot_to_systems()

## Authenticates locally without cloud network dependency
func login_local(p_callsign: String, p_squadron: String = "404th Vanguard Strike Wing", p_remember: bool = true) -> void:
	var clean_cs = p_callsign.strip_edges().to_upper()
	if clean_cs.is_empty():
		clean_cs = "VANGUARD-LEAD"
		
	callsign = clean_cs
	rank = "LIEUTENANT"
	squadron = p_squadron if not p_squadron.strip_edges().is_empty() else "404th Vanguard Strike Wing"
	token = ""
	email = ""
	is_email_verified = false
	pilot_id = "local-" + str(randi() % 10000)
	remember_me = p_remember
	is_authenticated = true
	
	if remember_me:
		_save_profile()
	else:
		_clear_saved_file()
		
	print(">>> [AuthManager] Local Pilot Authenticated: %s [%s] (%s)" % [callsign, rank, squadron])
	_sync_pilot_to_systems()
	auth_success.emit(get_active_profile())

## Generates a random guest callsign for instant arcade jump-in
func quick_sortie() -> void:
	var tactical_names = ["VIPER-1", "GHOST-4", "REAPER-7", "HUNTER-2", "APEX-9", "PHANTOM-3", "TALON-5", "COBRA-8"]
	var chosen = tactical_names[randi() % tactical_names.size()]
	login_local(chosen, "404th Vanguard Strike Wing", false)

## Authenticates against Cloudflare D1 database via /api/auth/login
func login_cloud(identifier: String, password: String, p_remember: bool = true) -> void:
	if identifier.strip_edges().is_empty() or password.is_empty():
		auth_failed.emit("Callsign and password are required.")
		return
		
	remember_me = p_remember
	pending_action = "login"
	
	var payload = {
		"callsign_or_email": identifier.strip_edges(),
		"password": password
	}
	
	var headers = ["Content-Type: application/json"]
	var err = http_request.request(CLOUD_API_BASE + "/login", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		auth_failed.emit("Failed to initiate cloud connection: Error %d" % err)

## Registers a new pilot in Cloudflare D1 database via /api/auth/register
func register_cloud(p_callsign: String, email: String, password: String, p_squadron: String = "404th Vanguard Strike Wing", p_remember: bool = true) -> void:
	if p_callsign.strip_edges().is_empty() or password.is_empty():
		auth_failed.emit("Callsign and password are required.")
		return
		
	remember_me = p_remember
	pending_action = "register"
	
	var payload = {
		"callsign": p_callsign.strip_edges().to_upper(),
		"email": email.strip_edges(),
		"password": password,
		"squadron": p_squadron
	}
	
	var headers = ["Content-Type: application/json"]
	var err = http_request.request(CLOUD_API_BASE + "/register", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		auth_failed.emit("Failed to initiate cloud connection: Error %d" % err)

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		var err_str = "Network connection failed (Result code %d)" % result
		if pending_action in ["verify_code", "resend_code"]:
			email_verification_failed.emit(err_str)
		else:
			auth_failed.emit(err_str)
		return
		
	var body_str = body.get_string_from_utf8()
	var parsed = JSON.parse_string(body_str)
	if typeof(parsed) != TYPE_DICTIONARY:
		var err_str = "Invalid server response format (HTTP %d)" % response_code
		if pending_action in ["verify_code", "resend_code"]:
			email_verification_failed.emit(err_str)
		else:
			auth_failed.emit(err_str)
		return
		
	var data: Dictionary = parsed
	if response_code >= 200 and response_code < 300:
		if pending_action == "verify_code":
			is_email_verified = true
			if remember_me:
				_save_profile()
			print(">>> [AuthManager] Email verified successfully with Brevo clearance code.")
			email_verified_success.emit()
			return
		elif pending_action == "resend_code":
			print(">>> [AuthManager] Brevo verification code re-dispatched.")
			verification_code_resent.emit()
			return

		var pilot_data = data.get("pilot", {})
		callsign = pilot_data.get("callsign", "PILOT").to_upper()
		rank = pilot_data.get("rank", "FLIGHT CADET")
		squadron = pilot_data.get("squadron", "404th Vanguard Strike Wing")
		pilot_id = str(pilot_data.get("id", ""))
		email = pilot_data.get("email", "")
		is_email_verified = bool(pilot_data.get("email_verified", 0))
		token = data.get("token", "")
		if pilot_data.has("stats") and typeof(pilot_data["stats"]) == TYPE_DICTIONARY:
			stats = pilot_data["stats"]
			
		var rm = get_node_or_null("/root/RewardManager")
		if rm and rm.has_method("load_save_data"):
			if data.has("save_data") and typeof(data["save_data"]) == TYPE_DICTIONARY and data["save_data"].has("rewards"):
				rm.load_save_data(data["save_data"]["rewards"])
			elif pilot_data.has("rewards"):
				rm.load_save_data(pilot_data["rewards"])
			elif data.has("record") and typeof(data["record"]) == TYPE_DICTIONARY and data["record"].has("stars"):
				rm.stars = int(data["record"]["stars"])
			
		is_authenticated = true
		
		if remember_me:
			_save_profile()
		else:
			_clear_saved_file()
			
		print(">>> [AuthManager] Cloud Pilot Authenticated: %s [%s] (%s) // Verified: %s" % [callsign, rank, squadron, str(is_email_verified)])
		_sync_pilot_to_systems()
		auth_success.emit(get_active_profile())
		if not is_email_verified and not email.is_empty():
			email_verification_required.emit(email)
	else:
		var error_msg = data.get("error", data.get("message", "Authentication rejected by station command."))
		if pending_action in ["verify_code", "resend_code"]:
			email_verification_failed.emit(error_msg)
		else:
			auth_failed.emit(error_msg)

## Submits 6-digit email verification code to /api/auth/verify
func verify_email_code(code: String) -> void:
	var clean_code = code.strip_edges().to_upper()
	if clean_code.is_empty():
		email_verification_failed.emit("Clearance code cannot be empty.")
		return
		
	pending_action = "verify_code"
	var payload = {
		"code": clean_code,
		"email": email
	}
	var headers = ["Content-Type: application/json"]
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
		
	var err = http_request.request(CLOUD_API_BASE + "/verify", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		email_verification_failed.emit("Failed to connect to verification server: %d" % err)

## Requests re-dispatch of the 6-digit verification code via /api/auth/resend-verification
func resend_verification_email() -> void:
	if email.is_empty():
		email_verification_failed.emit("No email associated with current pilot.")
		return
		
	pending_action = "resend_code"
	var payload = {
		"email": email
	}
	var headers = ["Content-Type: application/json"]
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
		
	var err = http_request.request(CLOUD_API_BASE + "/resend-verification", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		email_verification_failed.emit("Failed to connect to verification server: %d" % err)

## Logs out active pilot, clears memory and saved state
func logout() -> void:
	is_authenticated = false
	callsign = ""
	rank = "FLIGHT CADET"
	squadron = "404th Vanguard Strike Wing"
	token = ""
	pilot_id = ""
	email = ""
	is_email_verified = false
	stats = {
		"total_sorties": 0,
		"total_kills": 0,
		"total_flight_time_sec": 0,
		"highest_mission_unlocked": "M01"
	}
	_clear_saved_file()
	print(">>> [AuthManager] Pilot logged out.")
	logged_out.emit()

func _save_profile() -> void:
	var data = {
		"callsign": callsign,
		"rank": rank,
		"squadron": squadron,
		"token": token,
		"pilot_id": pilot_id,
		"email": email,
		"is_email_verified": is_email_verified,
		"remember_me": true,
		"stats": stats
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()

func _clear_saved_file() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

## Synchronizes active pilot identity into SaveManager, NetworkManager, and NetworkControllerServer
func _sync_pilot_to_systems() -> void:
	if not is_inside_tree():
		return

	# 1. Sync to NetworkManager (for PvP Arena multiplayer)
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr and "player_callsign" in net_mgr:
		net_mgr.player_callsign = callsign
		
	# 2. Sync to SaveManager (campaign profile)
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("set"):
		# Update profile metadata for save games
		pass
		
	# 3. Sync to NetworkControllerServer (Mobile HOTAS pairing)
	var controller_server = get_node_or_null("/root/NetworkControllerServer")
	if controller_server:
		# If mobile pilot connects, default host pilot callsign is updated
		pass

## Logs a completed battle/sortie outcome and updates career stats
func record_battle_result(theater: String, outcome: String, kills: int, duration_sec: float) -> void:
	if not stats.has("total_sorties"): stats["total_sorties"] = 0
	if not stats.has("total_kills"): stats["total_kills"] = 0
	if not stats.has("total_flight_time_sec"): stats["total_flight_time_sec"] = 0.0
	if not stats.has("battles_won"): stats["battles_won"] = 0
	if not stats.has("battles_lost"): stats["battles_lost"] = 0
	if not stats.has("battle_history"): stats["battle_history"] = []
	
	stats["total_sorties"] = int(stats["total_sorties"]) + 1
	stats["total_kills"] = int(stats["total_kills"]) + kills
	stats["total_flight_time_sec"] = float(stats["total_flight_time_sec"]) + duration_sec
	
	var is_win = outcome.to_upper() in ["VICTORY", "WON", "SUCCESS"]
	if is_win:
		stats["battles_won"] = int(stats["battles_won"]) + 1
	else:
		stats["battles_lost"] = int(stats["battles_lost"]) + 1
		
	var cfg = get_node_or_null("/root/ConfigManager") if is_inside_tree() else null
	var net_ctrl = get_node_or_null("/root/NetworkControllerServer") if is_inside_tree() else null
	var is_phone = net_ctrl and net_ctrl.connected_clients.size() > 0
	var is_az = cfg.is_azerty if cfg else true
	var controls_str = "PHONE GYRO" if is_phone else ("AZERTY" if is_az else "QWERTY")
	stats["preferred_controls"] = controls_str
		
	var entry = {
		"timestamp": Time.get_datetime_string_from_system(),
		"date": Time.get_date_string_from_system(),
		"theater": theater,
		"outcome": outcome,
		"kills": kills,
		"duration_sec": round(duration_sec),
		"controls": controls_str
	}
	var hist: Array = stats["battle_history"]
	hist.append(entry)
	if hist.size() > 25:
		hist.pop_front()
	stats["battle_history"] = hist
	
	if remember_me:
		_save_profile()
	print(">>> [AuthManager] Combat engagement logged: %s (%s) // %d kills // Career sorties: %d" % [
		theater, outcome, kills, stats["total_sorties"]
	])
	
	# Auto-sync cloud if authenticated
	sync_cloud_save()

## Synchronizes combat stats and savegame to Cloudflare D1 via /api/pilot/sync
func sync_cloud_save() -> void:
	if token.is_empty():
		return
		
	var sync_request = HTTPRequest.new()
	add_child(sync_request)
	sync_request.timeout = 6.0
	
	var payload = {
		"total_sorties": stats.get("total_sorties", 0),
		"total_kills": stats.get("total_kills", 0),
		"total_flight_time_sec": stats.get("total_flight_time_sec", 0.0),
		"highest_mission_unlocked": stats.get("highest_mission_unlocked", "M01"),
		"save_data": {
			"stats": stats,
			"rank": rank,
			"squadron": squadron,
			"callsign": callsign
		}
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	]
	
	sync_request.request_completed.connect(func(_res, _code, _h, _b):
		sync_request.queue_free()
	)
	sync_request.request("https://project-vanguard.pages.dev/api/pilot/sync", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
