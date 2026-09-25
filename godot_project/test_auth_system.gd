extends SceneTree

## Automated Headless Test for Vanguard Pilot Authentication & Login Prompt System
## Validates AuthManager local login, quick sortie, profile persistence,
## logout lifecycle, and LoginDialog signals.

const LoginDialogScene = preload("res://login_dialog.tscn")

var auth_mgr: Node = null
var test_dialog: Control = null
var step: int = 0
var timer: float = 0.0

func _init() -> void:
	print("=================================================================")
	print(">>> Project Vanguard: Pilot Authentication Test Suite <<<")
	print("=================================================================")
	
	# 1. Setup AuthManager
	auth_mgr = root.get_node_or_null("AuthManager")
	if not auth_mgr:
		auth_mgr = preload("res://auth_manager.gd").new()
		root.add_child(auth_mgr)
	
	print("[PASS] AuthManager instance created.")
	
	# 2. Test Local Authentication
	auth_mgr.login_local("VIPER", "Helion Orbital Reconnaissance", true)
	if not auth_mgr.is_authenticated:
		push_error("Failed: is_authenticated is false after login_local!")
		quit(1)
		return
		
	if auth_mgr.callsign != "VIPER":
		push_error("Failed: callsign mismatch. Expected 'VIPER', got '%s'" % auth_mgr.callsign)
		quit(1)
		return
		
	if auth_mgr.squadron != "Helion Orbital Reconnaissance":
		push_error("Failed: squadron mismatch. Got '%s'" % auth_mgr.squadron)
		quit(1)
		return
		
	print("[PASS] Local authentication verified: Callsign=%s, Rank=%s, Squadron=%s" % [auth_mgr.callsign, auth_mgr.rank, auth_mgr.squadron])
	
	# 3. Test Profile Persistence
	var save_path = "user://pilot_profile.json"
	if not FileAccess.file_exists(save_path):
		push_error("Failed: %s was not written to disk!" % save_path)
		quit(1)
		return
	print("[PASS] Pilot profile persisted to disk: %s" % save_path)
	
	# 4. Test Quick Sortie (Guest Mode)
	auth_mgr.quick_sortie()
	if not auth_mgr.is_authenticated or auth_mgr.callsign == "VIPER":
		push_error("Failed: Quick sortie did not randomize callsign!")
		quit(1)
		return
	print("[PASS] Quick Sortie randomized callsign: %s" % auth_mgr.callsign)
	
	# 5. Test Logout Lifecycle
	auth_mgr.logout()
	if auth_mgr.is_authenticated or not auth_mgr.callsign.is_empty():
		push_error("Failed: Logout did not reset authentication state!")
		quit(1)
		return
	print("[PASS] Logout lifecycle verified: active profile cleared.")
	
	# 6. Instantiate LoginDialog
	test_dialog = LoginDialogScene.instantiate()
	root.add_child(test_dialog)
	test_dialog.login_completed.connect(func(profile):
		print("[PASS] LoginDialog emitted login_completed: Callsign=%s, Rank=%s" % [profile.get("callsign", ""), profile.get("rank", "")])
		print("\n=================================================================")
		print(">>> ALL PILOT AUTHENTICATION TESTS PASSED 100%! <<<")
		print("=================================================================\n")
		quit(0)
	)

func _process(delta: float) -> bool:
	timer += delta
	if step == 0 and timer > 0.05:
		if test_dialog and test_dialog.callsign_input:
			print("[PASS] LoginDialog ready: simulating pilot typing 'TOPGUN'...")
			test_dialog.callsign_input.text = "TOPGUN"
			test_dialog._on_auth_pressed()
			step = 1
	if timer > 4.0:
		push_error("Pilot authentication test timed out!")
		quit(1)
		return true
	return false
