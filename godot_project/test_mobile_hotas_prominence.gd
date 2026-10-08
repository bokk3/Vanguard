extends SceneTree

## TestMobileHotasProminence: Validates that Mobile HOTAS UI is prominently exposed
## in HomeMenu (Hangar) and PauseMenu (In-Flight) and responds to F3 and client links.

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n>>> Testing Mobile HOTAS Prominence & Shortcuts in HomeMenu and PauseMenu...")
	
	# 1. Test HomeMenu
	var home_scene = load("res://home_menu.tscn")
	assert(home_scene != null, "home_menu.tscn must load")
	var home = home_scene.instantiate()
	root.add_child(home)
	
	# Check banner button above RootMenu
	var banner_btn = home.get_node_or_null("%HotasBannerBtn") as Button
	assert(banner_btn != null, "HotasBannerBtn must exist in home_menu")
	assert(banner_btn.visible, "HotasBannerBtn must be visible on startup")
	print("[PASS] HotasBannerBtn verified at top of hangar menu: '%s'" % banner_btn.text)
	
	# Check CategoryHotasBtn in RootMenu
	var cat_hotas_btn = home.get_node_or_null("%CategoryHotasBtn") as Button
	assert(cat_hotas_btn != null, "CategoryHotasBtn must exist in RootMenu")
	assert(cat_hotas_btn.visible, "CategoryHotasBtn must be visible in RootMenu")
	print("[PASS] CategoryHotasBtn verified in RootMenu: '%s'" % cat_hotas_btn.text)
	
	# Check MobileHotasBtn in SubmenuMultiplayer
	var multi_hotas_btn = home.get_node_or_null("%MobileHotasBtn") as Button
	assert(multi_hotas_btn != null, "MobileHotasBtn must exist in SubmenuMultiplayer")
	print("[PASS] MobileHotasBtn verified in SubmenuMultiplayer: '%s'" % multi_hotas_btn.text)
	
	# Test F3 input in HomeMenu
	var f3_event = InputEventKey.new()
	f3_event.pressed = true
	f3_event.keycode = KEY_F3
	home._unhandled_input(f3_event)
	
	var qr_dialog = home.get_node_or_null("UI/QRJoinDialog")
	assert(qr_dialog != null, "QRJoinDialog must be instantiated on F3 in HomeMenu")
	assert(qr_dialog.visible, "QRJoinDialog must be visible on F3")
	print("[PASS] F3 correctly toggled QRJoinDialog in HomeMenu!")
	
	# Test simulated pilot connect
	home._on_mobile_pilot_joined("VIPER-1", 1)
	assert("LINKED" in banner_btn.text, "Banner must show LINKED on connect")
	assert("LINKED" in cat_hotas_btn.text, "Category button must show LINKED on connect")
	assert("LINKED" in multi_hotas_btn.text, "Multiplayer button must show LINKED on connect")
	print("[PASS] Live Pilot Link UI updates verified across all hangar buttons!")
	
	# Test simulated pilot disconnect
	home._on_mobile_pilot_disconnected("VIPER-1", 1)
	assert("SCAN QR" in banner_btn.text, "Banner must reset to SCAN QR on disconnect")
	assert("MOBILE PHONE HOTAS" in cat_hotas_btn.text, "Category button must reset to default on disconnect")
	print("[PASS] Pilot Disconnect UI resets verified!")
	
	home.queue_free()
	
	# 2. Test PauseMenu
	var pause_scene = load("res://pause_menu.tscn")
	assert(pause_scene != null, "pause_menu.tscn must load")
	var pause = pause_scene.instantiate()
	root.add_child(pause)
	
	var pause_hotas_btn = pause.get_node_or_null("%MobileHotasPauseBtn") as Button
	assert(pause_hotas_btn != null, "MobileHotasPauseBtn must exist in PauseMenu")
	print("[PASS] MobileHotasPauseBtn verified in PauseMenu: '%s'" % pause_hotas_btn.text)
	
	# Test F3 in PauseMenu while paused
	pause.pause_flight()
	assert(pause.visible, "PauseMenu must be visible after pause_flight()")
	
	pause._unhandled_input(f3_event)
	var pause_qr = pause.find_child("QRJoinDialog", true, false)
	assert(pause_qr != null, "QRJoinDialog must be instantiated on F3 in PauseMenu")
	assert(pause_qr.visible, "QRJoinDialog must be visible on F3 in PauseMenu")
	print("[PASS] F3 correctly toggled QRJoinDialog in PauseMenu!")
	
	# Test pilot connect in PauseMenu
	pause._on_pilot_connected("VIPER-1", 1)
	assert("LINKED" in pause_hotas_btn.text, "PauseMenu button must show LINKED on connect")
	pause.queue_free()
	
	print("\n>>> ALL MOBILE HOTAS PROMINENCE TESTS PASSED 100%! <<<\n")
	quit(0)
