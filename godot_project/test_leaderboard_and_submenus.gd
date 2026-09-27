extends SceneTree

## Test suite for HomeMenu Submenus and Global Leaderboard Dialog
var timer: float = 0.0
var step: int = 0
var home_menu: Node = null
var lb_dialog: Node = null

func _init() -> void:
	print("=================================================================")
	print(">>> Project Vanguard: Leaderboard & Submenus Test Suite <<<")
	print("=================================================================")

func _process(delta: float) -> bool:
	timer += delta

	# Step 0: Instantiate HomeMenu
	if step == 0:
		var scene = load("res://home_menu.tscn")
		assert(scene != null, "home_menu.tscn must load successfully!")
		home_menu = scene.instantiate()
		root.add_child(home_menu)
		current_scene = home_menu
		
		# Verify RootMenu is visible by default
		var root_menu = home_menu.get_node("%RootMenu")
		assert(root_menu != null and root_menu.visible, "RootMenu must be visible on init!")
		
		# Verify submenus are hidden by default
		assert(not home_menu.get_node("%SubmenuCampaign").visible, "SubmenuCampaign must be hidden initially!")
		assert(not home_menu.get_node("%SubmenuMultiplayer").visible, "SubmenuMultiplayer must be hidden initially!")
		assert(not home_menu.get_node("%SubmenuIntel").visible, "SubmenuIntel must be hidden initially!")
		assert(not home_menu.get_node("%SubmenuSettings").visible, "SubmenuSettings must be hidden initially!")
		
		print("[PASS] HomeMenu initialized with RootMenu visible and submenus collapsed.")
		step = 1
		timer = 0.0

	# Step 1: Test navigating into Campaign submenu and back
	elif step == 1:
		home_menu._open_submenu("campaign")
		assert(not home_menu.get_node("%RootMenu").visible, "RootMenu must be hidden when submenu is open!")
		assert(home_menu.get_node("%SubmenuCampaign").visible, "SubmenuCampaign must be visible!")
		assert(home_menu.current_active_submenu == home_menu.get_node("%SubmenuCampaign"), "current_active_submenu must point to SubmenuCampaign!")
		
		# Return to main
		home_menu._close_submenu()
		assert(home_menu.get_node("%RootMenu").visible, "RootMenu must be visible after close!")
		assert(not home_menu.get_node("%SubmenuCampaign").visible, "SubmenuCampaign must be hidden after close!")
		assert(home_menu.current_active_submenu == null, "current_active_submenu must be null!")
		print("[PASS] SubmenuCampaign navigation and return verified.")
		step = 2
		timer = 0.0

	# Step 2: Test navigating into Multiplayer submenu and back
	elif step == 2:
		home_menu._open_submenu("multiplayer")
		assert(home_menu.get_node("%SubmenuMultiplayer").visible, "SubmenuMultiplayer must be visible!")
		home_menu._close_submenu()
		assert(home_menu.get_node("%RootMenu").visible, "RootMenu must be restored!")
		print("[PASS] SubmenuMultiplayer navigation and return verified.")
		step = 3
		timer = 0.0

	# Step 3: Test navigating into Intel submenu and opening Leaderboard
	elif step == 3:
		home_menu._open_submenu("intel")
		assert(home_menu.get_node("%SubmenuIntel").visible, "SubmenuIntel must be visible!")
		
		# Open LeaderboardDialog
		home_menu._show_leaderboard_dialog()
		lb_dialog = home_menu.get_node("%LeaderboardDialog")
		assert(lb_dialog != null and lb_dialog.visible, "LeaderboardDialog must be visible!")
		print("[PASS] LeaderboardDialog opened from Intel submenu.")
		step = 4
		timer = 0.0

	# Step 4: Test LeaderboardDialog category switching and ESC handling
	elif step == 4:
		# Switch to M01 category
		lb_dialog._switch_category("M01")
		assert(lb_dialog.current_category == "M01", "Category should be M01!")
		
		# Switch to M02 category
		lb_dialog._switch_category("M02")
		assert(lb_dialog.current_category == "M02", "Category should be M02!")
		
		# Switch back to global
		lb_dialog._switch_category("global")
		assert(lb_dialog.current_category == "global", "Category should be global!")
		
		# Close LeaderboardDialog via close_leaderboard
		lb_dialog.close_leaderboard()
		assert(not lb_dialog.visible, "LeaderboardDialog should be hidden after close!")
		
		# Close submenu
		home_menu._close_submenu()
		assert(home_menu.get_node("%RootMenu").visible, "RootMenu should be visible!")
		print("[PASS] LeaderboardDialog category switching and closure verified.")
		step = 5
		timer = 0.0

	# Step 5: Test ESC key handling
	elif step == 5:
		# Open settings submenu
		home_menu._open_submenu("settings")
		assert(home_menu.get_node("%SubmenuSettings").visible, "SubmenuSettings must be visible!")
		
		# Simulate ESC key event
		var esc_event = InputEventKey.new()
		esc_event.pressed = true
		esc_event.keycode = KEY_ESCAPE
		home_menu._unhandled_input(esc_event)
		
		assert(home_menu.get_node("%RootMenu").visible, "RootMenu should be visible after ESC key pressed!")
		assert(not home_menu.get_node("%SubmenuSettings").visible, "SubmenuSettings should be closed after ESC!")
		print("[PASS] ESC key handled successfully to collapse submenu.")
		
		print(">>> ALL SUBMENU & LEADERBOARD TESTS PASSED (100%) <<<")
		quit(0)
		return true

	return false
