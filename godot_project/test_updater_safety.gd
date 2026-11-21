extends SceneTree

## Headless tests for the updater's download checks: zip entry validation,
## size and SHA-256 verification, and version comparison.
## Run: godot --headless --path godot_project -s test_updater_safety.gd

const Updater = preload("res://updater.gd")

var failures: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("[PASS] ", label)
	else:
		failures += 1
		printerr("[FAIL] ", label)

func _init() -> void:
	print(">>> Updater safety tests <<<")

	# Zip entries
	for good in ["project_vanguard.exe", "data/pack.pck", "a/b/c.txt", "dir/", "file..name.txt"]:
		_check(Updater.is_safe_zip_entry(good), "accepts zip entry %s" % good)
	for bad in ["", "../evil.exe", "a/../../evil", "/etc/passwd", "C:/Windows/evil.dll", "..\\evil.bat", "a\\..\\..\\b"]:
		_check(not Updater.is_safe_zip_entry(bad), "rejects zip entry %s" % bad)

	# Download verification
	var path = OS.get_user_data_dir().path_join("updater_test.bin")
	var data = "vanguard update payload".to_utf8_buffer()
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	var sha = ctx.finish().hex_encode()

	_check(Updater.verify_download(path, data.size(), sha) == "", "accepts matching size and hash")
	_check(Updater.verify_download(path, 0, "") == "", "accepts when nothing is known")
	_check(Updater.verify_download(path, data.size() + 1, "") != "", "rejects wrong size")
	_check(Updater.verify_download(path, data.size(), "00" + sha.substr(2)) != "", "rejects wrong hash")
	_check(Updater.verify_download(path + ".missing", 0, "") != "", "rejects missing file")
	DirAccess.remove_absolute(path)

	# Version comparison
	_check(Updater.is_version_newer("v0.9.8", "0.9.7"), "0.9.8 is newer than 0.9.7")
	_check(not Updater.is_version_newer("v0.9.7", "0.9.7"), "same version is not newer")
	_check(Updater.is_version_newer("0.10.0", "0.9.7"), "0.10.0 is newer than 0.9.7")
	_check(Updater.is_version_newer("0.9.7", "0.9.7-rc1"), "release is newer than its prerelease")

	if failures == 0:
		print(">>> ALL UPDATER SAFETY TESTS PASSED <<<")
		quit(0)
	else:
		printerr(">>> %d UPDATER TEST(S) FAILED <<<" % failures)
		quit(1)
