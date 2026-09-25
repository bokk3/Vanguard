extends SceneTree

func _init() -> void:
	print(">>> Verifying all newly created and updated scenes...")
	
	var mode_dialog_scene = load("res://mode_selector_dialog.tscn")
	assert(mode_dialog_scene != null, "mode_selector_dialog.tscn must load")
	var mode_instance = mode_dialog_scene.instantiate()
	root.add_child(mode_instance)
	print("[PASS] ModeSelectorDialog instantiated successfully.")
	mode_instance.queue_free()

	var stats_dialog_scene = load("res://combat_stats_dialog.tscn")
	assert(stats_dialog_scene != null, "combat_stats_dialog.tscn must load")
	var stats_instance = stats_dialog_scene.instantiate()
	root.add_child(stats_instance)
	print("[PASS] CombatStatsDialog instantiated successfully.")
	stats_instance.queue_free()

	var qr_dialog_scene = load("res://qr_join_dialog.tscn")
	assert(qr_dialog_scene != null, "qr_join_dialog.tscn must load")
	var qr_instance = qr_dialog_scene.instantiate()
	root.add_child(qr_instance)
	print("[PASS] QRJoinDialog instantiated successfully.")
	qr_instance.queue_free()

	var home_menu_scene = load("res://home_menu.tscn")
	assert(home_menu_scene != null, "home_menu.tscn must load")
	var home_instance = home_menu_scene.instantiate()
	root.add_child(home_instance)
	print("[PASS] HomeMenu instantiated successfully.")
	home_instance.queue_free()

	var pvp_menu_scene = load("res://pvp_menu.tscn")
	assert(pvp_menu_scene != null, "pvp_menu.tscn must load")
	var pvp_instance = pvp_menu_scene.instantiate()
	root.add_child(pvp_instance)
	print("[PASS] PvPMenu instantiated successfully.")
	pvp_instance.queue_free()

	print(">>> ALL SCENES VERIFIED 100% OK! <<<")
	quit(0)
