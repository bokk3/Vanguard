extends SceneTree

## Automated Headless Test for Vanguard Auto-Updater
## Verifies semver comparison, markdown parsing, asset matching, ZIP extraction, and script generation.

func _init() -> void:
	print("--- [TEST] Starting Vanguard Auto-Updater Test Suite ---")
	
	test_version_comparison()
	test_markdown_conversion()
	test_asset_matching()
	test_zip_extraction_and_script_prep()
	test_updater_autoload_presence()
	
	print("\n>>> ALL AUTO-UPDATER TESTS PASSED SUCCESSFULLY (Exit code 0) <<<")
	quit(0)

func test_version_comparison() -> void:
	print("\n[TEST 1] Verifying Semantic Version Comparison...")
	var UpdaterScript = load("res://updater.gd")
	assert(UpdaterScript != null, "Failed to load updater.gd")
	
	# Basic increments
	assert(UpdaterScript.is_version_newer("0.8.0", "0.7.0") == true, "0.8.0 should be newer than 0.7.0")
	assert(UpdaterScript.is_version_newer("v0.8.0", "0.7.0") == true, "v0.8.0 should strip 'v' prefix")
	assert(UpdaterScript.is_version_newer("1.0.0", "0.9.9") == true, "1.0.0 should be newer than 0.9.9")
	assert(UpdaterScript.is_version_newer("0.7.1", "0.7.0") == true, "0.7.1 should be newer than 0.7.0")
	
	# Equality & older versions
	assert(UpdaterScript.is_version_newer("0.7.0", "0.7.0") == false, "Identical versions should not be newer")
	assert(UpdaterScript.is_version_newer("0.6.9", "0.7.0") == false, "Older minor/patch should not be newer")
	assert(UpdaterScript.is_version_newer("0.5.0", "0.7.0") == false, "0.5.0 should not be newer than 0.7.0")
	
	# Prerelease vs Release
	assert(UpdaterScript.is_version_newer("0.7.0", "0.7.0-alpha") == true, "Final release 0.7.0 should be newer than 0.7.0-alpha")
	assert(UpdaterScript.is_version_newer("0.7.0-alpha", "0.7.0") == false, "0.7.0-alpha should not be newer than final 0.7.0")
	assert(UpdaterScript.is_version_newer("0.7.0-beta", "0.7.0-alpha") == true, "0.7.0-beta should be newer than 0.7.0-alpha")
	
	print("  ✓ Semantic version comparisons nominal.")

func test_markdown_conversion() -> void:
	print("\n[TEST 2] Verifying Markdown -> BBCode conversion...")
	var UpdaterScript = load("res://updater.gd")
	
	var sample_md = """# Major Update
## Mission 02 Dossier
- Added **new weapon**: `20mm Rotary Autocannon`
* Improved *flight telemetry*
> Radio communications restored."""
	
	var bb = UpdaterScript.markdown_to_bbcode(sample_md)
	assert(bb.contains("[b][color=#ffcc00]MISSION 02 DOSSIER[/color][/b]"), "Subheading not converted correctly")
	assert(bb.contains("Added [b]new weapon[/b]: [color=#00f0ff]20mm Rotary Autocannon[/color]"), "Bullets or bold/code not formatted correctly")
	print("  ✓ Markdown formatted into BBCode properly:\n" + bb)

func test_asset_matching() -> void:
	print("\n[TEST 3] Verifying Platform Asset Matching...")
	var updater = load("res://updater.gd").new()
	
	var mock_assets = [
		{"name": "project_vanguard_windows.zip", "browser_download_url": "https://example.com/win.zip", "size": 45000000},
		{"name": "project_vanguard_linux.zip", "browser_download_url": "https://example.com/linux.zip", "size": 43000000},
		{"name": "project_vanguard_macos.zip", "browser_download_url": "https://example.com/mac.zip", "size": 46000000}
	]
	
	var matched = updater._find_matching_asset(mock_assets)
	var os_name = OS.get_name().to_lower()
	print("  Current OS: %s -> Matched Asset: %s" % [os_name, matched.get("name", "NONE")])
	
	if os_name == "windows":
		assert(matched.get("name") == "project_vanguard_windows.zip", "Windows must match windows.zip")
	elif os_name in ["linux", "freebsd"]:
		assert(matched.get("name") == "project_vanguard_linux.zip", "Linux must match linux.zip")
	elif os_name == "macos":
		assert(matched.get("name") == "project_vanguard_macos.zip", "macOS must match macos.zip")
	
	updater.queue_free()
	print("  ✓ Platform asset matching verified.")

func test_zip_extraction_and_script_prep() -> void:
	print("\n[TEST 4] Verifying ZIP archive creation, extraction and launcher generation...")
	var updater = load("res://updater.gd").new()
	root.add_child(updater)
	
	var staging = ProjectSettings.globalize_path("user://update_staging")
	DirAccess.make_dir_recursive_absolute(staging)
	
	var test_zip = staging.path_join("test_archive.zip")
	var packer = ZIPPacker.new()
	var err = packer.open(test_zip)
	assert(err == OK, "Failed to create test zip")
	
	packer.start_file("bin/vanguard_binary.test")
	packer.write_file("TEST_BINARY_PAYLOAD_V080".to_utf8_buffer())
	packer.close_file()
	
	packer.start_file("version.info")
	packer.write_file("VERSION=0.8.0".to_utf8_buffer())
	packer.close_file()
	packer.close()
	
	var extracted_dir = staging.path_join("extracted_test")
	var extract_ok = updater._extract_zip_archive(test_zip, extracted_dir)
	assert(extract_ok, "Extraction should succeed")
	
	var read_file = FileAccess.open(extracted_dir.path_join("version.info"), FileAccess.READ)
	assert(read_file != null, "Extracted file should exist")
	var text = read_file.get_as_text()
	read_file.close()
	assert(text == "VERSION=0.8.0", "Extracted content must match")
	print("  ✓ ZIP archive successfully extracted via ZIPReader.")
	
	var prep_ok = updater._prepare_launcher_script(extracted_dir)
	assert(prep_ok, "Launcher script preparation should succeed")
	assert(not updater._launcher_script_path.is_empty(), "Launcher path must be recorded")
	assert(FileAccess.file_exists(updater._launcher_script_path), "Launcher script file must exist on disk")
	print("  ✓ Launcher script written to: %s" % updater._launcher_script_path)
	
	# Clean up test files
	DirAccess.remove_absolute(test_zip)
	updater.queue_free()

func test_updater_autoload_presence() -> void:
	print("\n[TEST 5] Verifying UI instantiations & dialog bindings...")
	var home_scene = load("res://home_menu.tscn")
	assert(home_scene != null, "Failed to load home_menu.tscn")
	
	var inst = home_scene.instantiate()
	root.add_child(inst)
	
	var badge = inst.get_node_or_null("%UpdateBadgeBtn")
	assert(badge != null, "UpdateBadgeBtn must exist in HomeMenu")
	assert(badge.visible == false, "UpdateBadgeBtn should start hidden")
	
	var dialog = inst.get_node_or_null("%UpdateDialog")
	assert(dialog != null, "UpdateDialog must exist in HomeMenu")
	assert(dialog.visible == false, "UpdateDialog should start hidden")
	
	# Simulate showing dialog
	dialog.show_update_prompt("0.7.0", "0.8.0-alpha", "- New sorties available", 42000000)
	assert(dialog.visible == true, "Dialog should be visible after show_update_prompt()")
	
	inst.queue_free()
	print("  ✓ UI components verified.")
