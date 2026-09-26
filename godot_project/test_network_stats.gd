extends SceneTree

## Automated Test Suite: Fleet Operations Presence, Counters & Lobby Tracking (v0.8.2)

var timer: float = 0.0
var step: int = 0
var net_mgr: Node = null

func _init() -> void:
	print("=================================================================")
	print(">>> Project Vanguard: Fleet Operations Network Counters Suite <<<")
	print("=================================================================")

func _process(delta: float) -> bool:
	timer += delta

	# Step 0: Acquire NetworkManager autoload singleton
	if step == 0:
		net_mgr = root.get_node_or_null("NetworkManager")
		if not net_mgr:
			return false # Wait for autoload initialization
		
		print("[PASS] NetworkManager singleton active in root.")

		# 1. Verify default baseline values
		assert(net_mgr.registered_pilots >= 1420, "Baseline registered pilots must be at least 1,420!")
		assert(net_mgr.online_pilots >= 1, "Baseline online pilots must be at least 1!")
		assert(net_mgr.active_lobbies >= 0, "Active lobbies must be non-negative!")
		print("[PASS] Default baseline fleet counters verified: %d roster, %d online, %d lobbies." % [
			net_mgr.registered_pilots, net_mgr.online_pilots, net_mgr.active_lobbies
		])

		step = 1
		timer = 0.0

	# Step 1: Test JSON payload parsing and signal emission
	elif step == 1:
		var sig_data = {
			"received": false,
			"reg": 0,
			"online": 0,
			"lobbies": 0
		}

		var test_callable = func(r: int, o: int, l: int):
			sig_data["received"] = true
			sig_data["reg"] = r
			sig_data["online"] = o
			sig_data["lobbies"] = l

		net_mgr.network_stats_updated.connect(test_callable)

		var mock_response_json = JSON.stringify({
			"success": true,
			"registered_pilots": 1588,
			"online_pilots": 24,
			"active_lobbies": 5,
			"lobbies": [
				{
					"session_id": "sess-test-1",
					"host_callsign": "MAVERICK",
					"lobby_name": "TOPGUN COMBAT ARENA",
					"players": 2,
					"max_players": 2,
					"map": "Dusk Canyon"
				}
			]
		})

		net_mgr._on_stats_request_completed(OK, 200, PackedStringArray(), mock_response_json.to_utf8_buffer())

		assert(sig_data["received"], "network_stats_updated signal must be emitted upon stats payload reception!")
		assert(sig_data["reg"] == 1588, "Registered count must match parsed value (1588)!")
		assert(sig_data["online"] == 24, "Online count must match parsed value (24)!")
		assert(sig_data["lobbies"] == 5, "Lobbies count must match parsed value (5)!")
		assert(net_mgr.remote_lobbies.size() == 1, "Remote lobbies array must contain 1 lobby!")
		assert(net_mgr.remote_lobbies[0]["host_callsign"] == "MAVERICK", "Host callsign must match!")
		print("[PASS] Live stats payload ingestion and remote lobby parsing verified.")

		step = 2
		timer = 0.0

	# Step 2: Test HomeMenu FleetRadarBox UI rendering
	elif step == 2:
		var home_scene = load("res://home_menu.tscn")
		assert(home_scene != null, "home_menu.tscn must load!")
		var home_inst = home_scene.instantiate()
		root.add_child(home_inst)

		var fleet_label: Label = home_inst.get_node_or_null("%FleetStatsLabel")
		assert(fleet_label != null, "%FleetStatsLabel must exist in HomeMenu!")
		assert(fleet_label.text.contains("ONLINE: 24"), "FleetStatsLabel must display online count!")
		assert(fleet_label.text.contains("LOBBIES: 5"), "FleetStatsLabel must display lobbies count!")
		assert(fleet_label.text.contains("1,588"), "FleetStatsLabel must display formatted roster count!")
		print("[PASS] HomeMenu FleetRadarBox verified: '%s'" % fleet_label.text)
		home_inst.free()

		step = 3
		timer = 0.0

	# Step 3: Test ModeSelectorDialog FleetTelemetryLabel UI rendering
	elif step == 3:
		var mode_scene = load("res://mode_selector_dialog.tscn")
		assert(mode_scene != null, "mode_selector_dialog.tscn must load!")
		var mode_inst = mode_scene.instantiate()
		root.add_child(mode_inst)
		mode_inst.show_selector()

		var mode_label: Label = mode_inst.get_node_or_null("%FleetTelemetryLabel")
		assert(mode_label != null, "%FleetTelemetryLabel must exist in ModeSelectorDialog!")
		assert(mode_label.text.contains("24 PILOTS ONLINE"), "ModeSelectorDialog must display 24 pilots online!")
		assert(mode_label.text.contains("5 COMBAT LOBBIES ACTIVE"), "ModeSelectorDialog must display 5 combat lobbies!")
		print("[PASS] ModeSelectorDialog FleetTelemetryLabel verified: '%s'" % mode_label.text)
		mode_inst.free()

		step = 4
		timer = 0.0

	# Step 4: Test PvPMenu FleetTelemetryLabel UI rendering
	elif step == 4:
		var pvp_scene = load("res://pvp_menu.tscn")
		assert(pvp_scene != null, "pvp_menu.tscn must load!")
		var pvp_inst = pvp_scene.instantiate()
		root.add_child(pvp_inst)

		var pvp_label: Label = pvp_inst.get_node_or_null("%FleetTelemetryLabel")
		assert(pvp_label != null, "%FleetTelemetryLabel must exist in PvPMenu!")
		assert(pvp_label.text.contains("24 PILOTS ONLINE"), "PvPMenu must display 24 pilots online!")
		assert(pvp_label.text.contains("5 COMBAT LOBBIES ACTIVE"), "PvPMenu must display 5 combat lobbies active!")
		print("[PASS] PvPMenu FleetTelemetryLabel verified: '%s'" % pvp_label.text)
		pvp_inst.free()

		step = 5
		timer = 0.0

	# Step 5: Test Session Type state transitions during Host / Stop
	elif step == 5:
		assert(net_mgr.session_type == "PILOT", "Initial session type must be PILOT!")
		var host_err = net_mgr.host_game("TEST SQUADRON LOBBY", 7777, 1)
		assert(host_err == OK, "host_game must succeed!")
		assert(net_mgr.session_type == "LOBBY", "Session type must transition to LOBBY when hosting!")
		print("[PASS] Session type transition to LOBBY on host_game verified.")

		net_mgr.stop_network()
		assert(net_mgr.session_type == "PILOT", "Session type must revert to PILOT when stopping host!")
		print("[PASS] Session type reversion to PILOT on stop_network verified.")

		print("=================================================================")
		print(">>> ALL FLEET OPERATIONS NETWORK COUNTER TESTS PASSED 100%! <<<")
		print("=================================================================")
		quit(0)

	return false
