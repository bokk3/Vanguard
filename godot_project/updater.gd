extends Node

## Updater: Auto-updater singleton for Project Vanguard using GitHub Releases.
## Queries the GitHub Releases API silently, downloads assets with progress,
## extracts using ZIPReader, and delegates binary swap to a detached launcher script.

signal update_available(version: String, changelog: String, url: String, size_bytes: int)
signal download_progress(pct: float, downloaded_bytes: int, total_bytes: int)
signal update_ready()
signal update_error(message: String)

const REPO: String = "bokk3/Vanguard"
const API_URL: String = "https://api.github.com/repos/" + REPO + "/releases/latest"
const USER_AGENT: String = "ProjectVanguard-AutoUpdater"
const STAGING_REL_DIR: String = "user://update_staging"

var current_version: String = "0.7.4"
var available_version: String = ""
var changelog_text: String = ""
var download_url: String = ""
var asset_size_bytes: int = 0

var has_dismissed_prompt: bool = false
var is_downloading: bool = false
var is_ready_to_restart: bool = false

var _http_check: HTTPRequest
var _http_download: HTTPRequest
var _launcher_script_path: String = ""

func _ready() -> void:
	current_version = ProjectSettings.get_setting("application/config/version", "0.7.4")
	_setup_http_nodes()
	_ensure_directories()
	
	# Do not run update check in headless or automated test mode
	if DisplayServer.get_name() == "headless":
		return
		
	# Delay initial silent check by 1.0 second so game initialization completes cleanly
	get_tree().create_timer(1.0).timeout.connect(check_for_updates_silently)

func _setup_http_nodes() -> void:
	_http_check = HTTPRequest.new()
	_http_check.name = "HTTP_ReleaseCheck"
	_http_check.timeout = 10.0
	_http_check.request_completed.connect(_on_check_request_completed)
	add_child(_http_check)
	
	_http_download = HTTPRequest.new()
	_http_download.name = "HTTP_AssetDownload"
	_http_download.use_threads = true
	_http_download.request_completed.connect(_on_download_request_completed)
	add_child(_http_download)

func _ensure_directories() -> void:
	var staging_abs = ProjectSettings.globalize_path(STAGING_REL_DIR)
	if not DirAccess.dir_exists_absolute(staging_abs):
		DirAccess.make_dir_recursive_absolute(staging_abs)

func check_for_updates_silently() -> void:
	if is_downloading or is_ready_to_restart:
		return
	
	# Skip update checks on Web or mobile platforms
	var os_name = OS.get_name()
	if os_name in ["Web", "Android", "iOS"]:
		return
	
	var headers = PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: " + USER_AGENT
	])
	
	var err = _http_check.request(API_URL, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("[Updater] Silent check request could not be dispatched (err %d), skipping." % err)

func _on_check_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[Updater] Release check network result: %d (skipping silently)" % result)
		return
	
	if response_code != 200:
		# 404 = no releases yet, 403 = rate limit reached; both handled completely silently
		print("[Updater] GitHub API status code: %d (skipping silently)" % response_code)
		return
	
	var json_str = body.get_string_from_utf8()
	var parsed = JSON.parse_string(json_str)
	if not parsed or typeof(parsed) != TYPE_DICTIONARY:
		return
	
	var tag_name: String = str(parsed.get("tag_name", ""))
	if tag_name.is_empty():
		return
	
	if not is_version_newer(tag_name, current_version):
		print("[Updater] Current version %s is up-to-date with remote %s." % [current_version, tag_name])
		return
	
	# Match asset for current OS
	var assets: Array = parsed.get("assets", [])
	var target_asset: Dictionary = _find_matching_asset(assets)
	if target_asset.is_empty():
		print("[Updater] Newer release %s found, but no matching asset for platform '%s'." % [tag_name, OS.get_name()])
		return
	
	available_version = tag_name
	changelog_text = str(parsed.get("body", "No release notes provided."))
	download_url = str(target_asset.get("browser_download_url", ""))
	asset_size_bytes = int(target_asset.get("size", 0))
	
	print("[Updater] Update available: %s -> %s (%d bytes)" % [current_version, available_version, asset_size_bytes])
	emit_signal("update_available", available_version, changelog_text, download_url, asset_size_bytes)

func _find_matching_asset(assets: Array) -> Dictionary:
	var os_name = OS.get_name().to_lower()
	var search_keyword = ""
	
	match os_name:
		"windows":
			search_keyword = "windows"
		"linux", "freebsd":
			search_keyword = "linux"
		"macos":
			search_keyword = "macos"
		_:
			return {}
	
	for a in assets:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var a_name: String = str(a.get("name", "")).to_lower()
		if a_name.ends_with(".zip") and search_keyword in a_name:
			return a
	return {}

func start_download() -> void:
	if download_url.is_empty() or is_downloading:
		return
	
	var staging_abs = ProjectSettings.globalize_path(STAGING_REL_DIR)
	var zip_abs = staging_abs.path_join("update.zip")
	
	if FileAccess.file_exists(zip_abs):
		DirAccess.remove_absolute(zip_abs)
	
	_http_download.download_file = zip_abs
	is_downloading = true
	
	var headers = PackedStringArray([
		"Accept: application/octet-stream",
		"User-Agent: " + USER_AGENT
	])
	
	var err = _http_download.request(download_url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		is_downloading = false
		emit_signal("update_error", "Failed to initiate download (code %d)" % err)

func _process(_delta: float) -> void:
	if not is_downloading:
		return
	
	var downloaded = _http_download.get_downloaded_bytes()
	var total = asset_size_bytes
	if total <= 0:
		total = _http_download.get_body_size()
	
	var pct: float = 0.0
	if total > 0:
		pct = clampf(float(downloaded) / float(total) * 100.0, 0.0, 100.0)
	
	emit_signal("download_progress", pct, downloaded, total)

func _on_download_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	is_downloading = false
	
	if result != HTTPRequest.RESULT_SUCCESS or (response_code != 200 and response_code != 204 and response_code != 302):
		emit_signal("update_error", "Download failed (network code %d, HTTP %d)" % [result, response_code])
		return
	
	var staging_abs = ProjectSettings.globalize_path(STAGING_REL_DIR)
	var zip_abs = staging_abs.path_join("update.zip")
	var extracted_abs = staging_abs.path_join("extracted")
	
	# Extract ZIP archive
	var extract_ok = _extract_zip_archive(zip_abs, extracted_abs)
	if not extract_ok:
		emit_signal("update_error", "Failed to extract downloaded archive.")
		return
	
	# Generate platform launcher script
	var script_ok = _prepare_launcher_script(extracted_abs)
	if not script_ok:
		emit_signal("update_error", "Failed to prepare update launcher script.")
		return
	
	is_ready_to_restart = true
	emit_signal("update_ready")

func _extract_zip_archive(zip_path: String, out_dir: String) -> bool:
	if not DirAccess.dir_exists_absolute(out_dir):
		DirAccess.make_dir_recursive_absolute(out_dir)
	
	var reader = ZIPReader.new()
	var err = reader.open(zip_path)
	if err != OK:
		print("[Updater] ZIPReader failed to open archive: ", err)
		return false
	
	var files = reader.get_files()
	for entry in files:
		var dest = out_dir.path_join(entry)
		if entry.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(dest)
			continue
		
		var parent_dir = dest.get_base_dir()
		if not DirAccess.dir_exists_absolute(parent_dir):
			DirAccess.make_dir_recursive_absolute(parent_dir)
		
		var data = reader.read_file(entry)
		var f = FileAccess.open(dest, FileAccess.WRITE)
		if f:
			f.store_buffer(data)
			f.close()
		else:
			print("[Updater] Could not write extracted file: ", dest)
	
	reader.close()
	return true

func _prepare_launcher_script(extracted_dir: String) -> bool:
	var exe_path = OS.get_executable_path()
	var install_dir = exe_path.get_base_dir()
	var exe_name = exe_path.get_file()
	var staging_abs = ProjectSettings.globalize_path(STAGING_REL_DIR)
	
	var os_name = OS.get_name().to_lower()
	if os_name == "windows":
		var bat_path = staging_abs.path_join("apply_update.bat")
		var template = """@echo off
setlocal enabledelayedexpansion
set "LOG=%~dp0update_log.txt"
echo [%date% %time%] Project Vanguard Auto-Updater started > "!LOG!"
echo [%date% %time%] Target exe: {EXE_PATH} >> "!LOG!"
echo [%date% %time%] Waiting for running game process to quit... >> "!LOG!"
timeout /t 2 /nobreak >nul

set "INSTALL_DIR={INSTALL_DIR}"
set "EXTRACTED_SRC={EXTRACTED_SRC}"
set "EXE_NAME={EXE_NAME}"

echo [%date% %time%] Renaming existing executable... >> "!LOG!"
if exist "!INSTALL_DIR!\\!EXE_NAME!" (
    ren "!INSTALL_DIR!\\!EXE_NAME!" "!EXE_NAME!.old" >> "!LOG!" 2>&1
)

echo [%date% %time%] Overwriting files from staging... >> "!LOG!"
xcopy /E /Y /I "!EXTRACTED_SRC!\\*" "!INSTALL_DIR!\\" >> "!LOG!" 2>&1

echo [%date% %time%] Starting updated game binary... >> "!LOG!"
start "" "!INSTALL_DIR!\\!EXE_NAME!"

echo [%date% %time%] Cleaning up temporary files... >> "!LOG!"
if exist "!INSTALL_DIR!\\!EXE_NAME!.old" (
    del "!INSTALL_DIR!\\!EXE_NAME!.old" >> "!LOG!" 2>&1
)
del "%~f0" >> "!LOG!" 2>&1
"""
		var script_content = template \
			.replace("{EXE_PATH}", exe_path) \
			.replace("{INSTALL_DIR}", install_dir) \
			.replace("{EXTRACTED_SRC}", extracted_dir) \
			.replace("{EXE_NAME}", exe_name)
		
		var f = FileAccess.open(bat_path, FileAccess.WRITE)
		if not f:
			return false
		f.store_string(script_content)
		f.close()
		_launcher_script_path = bat_path
		return true
		
	elif os_name in ["linux", "freebsd", "macos"]:
		var sh_path = staging_abs.path_join("apply_update.sh")
		var is_mac = (os_name == "macos")
		var quarantine_fix = 'xattr -cr "$INSTALL_DIR" 2>/dev/null || true' if is_mac else ""
		
		var template = """#!/usr/bin/env bash
LOG="$(dirname "$0")/update_log.txt"
echo "[$(date)] Project Vanguard Auto-Updater started" > "$LOG"
echo "[$(date)] Waiting for game process to terminate..." >> "$LOG"
sleep 2

INSTALL_DIR="{INSTALL_DIR}"
EXTRACTED_SRC="{EXTRACTED_SRC}"
EXE_PATH="{EXE_PATH}"

echo "[$(date)] Overwriting files..." >> "$LOG"
cp -rf "$EXTRACTED_SRC"/* "$INSTALL_DIR"/ >> "$LOG" 2>&1

echo "[$(date)] Restoring execution permissions..." >> "$LOG"
chmod +x "$EXE_PATH" >> "$LOG" 2>&1

{QUARANTINE_FIX}

echo "[$(date)] Launching updated game..." >> "$LOG"
"$EXE_PATH" &

rm -- "$0" >> "$LOG" 2>&1
"""
		var script_content = template \
			.replace("{INSTALL_DIR}", install_dir) \
			.replace("{EXTRACTED_SRC}", extracted_dir) \
			.replace("{EXE_PATH}", exe_path) \
			.replace("{QUARANTINE_FIX}", quarantine_fix)
		
		var f = FileAccess.open(sh_path, FileAccess.WRITE)
		if not f:
			return false
		f.store_string(script_content)
		f.close()
		
		# Ensure execute bit is set on the script
		OS.execute("chmod", ["+x", sh_path])
		_launcher_script_path = sh_path
		return true
	
	return false

func apply_update_and_restart() -> void:
	if _launcher_script_path.is_empty():
		emit_signal("update_error", "No launcher script prepared.")
		return
	
	if not OS.has_feature("standalone"):
		emit_signal("update_error", "Running in editor mode: Cannot replace running editor executable.")
		print("[Updater] Update ready at: %s (Skipping swap in editor)" % _launcher_script_path)
		return
	
	var os_name = OS.get_name().to_lower()
	var pid: int = -1
	
	if os_name == "windows":
		pid = OS.create_process("cmd.exe", ["/c", _launcher_script_path])
	elif os_name in ["linux", "freebsd", "macos"]:
		pid = OS.create_process("/bin/bash", [_launcher_script_path])
	
	if pid > 0:
		print("[Updater] Spawned launcher script (PID: %d), exiting game process..." % pid)
		get_tree().quit(0)
	else:
		emit_signal("update_error", "Failed to spawn update launcher process.")

# ─────────────────────────────────────────────────────────────
# Static Utilities (Version parsing & BBCode conversion)
# ─────────────────────────────────────────────────────────────

static func parse_semver(v_str: String) -> Dictionary:
	var s = v_str.strip_edges().trim_prefix("v").trim_prefix("V")
	var parts = s.split("-", true, 1)
	var num_parts = parts[0].split(".")
	var major = int(num_parts[0]) if num_parts.size() > 0 else 0
	var minor = int(num_parts[1]) if num_parts.size() > 1 else 0
	var patch = int(num_parts[2]) if num_parts.size() > 2 else 0
	var prerelease = parts[1] if parts.size() > 1 else ""
	return {"major": major, "minor": minor, "patch": patch, "prerelease": prerelease}

static func is_version_newer(remote_v: String, local_v: String) -> bool:
	var r = parse_semver(remote_v)
	var l = parse_semver(local_v)
	
	if r.major != l.major:
		return r.major > l.major
	if r.minor != l.minor:
		return r.minor > l.minor
	if r.patch != l.patch:
		return r.patch > l.patch
	
	# When numeric segments match:
	# A stable release (empty prerelease) is newer than a prerelease (e.g. 0.7.0 > 0.7.0-alpha)
	if r.prerelease.is_empty() and not l.prerelease.is_empty():
		return true
	if not r.prerelease.is_empty() and l.prerelease.is_empty():
		return false
	
	# If both have prereleases, compare lexicographically
	if not r.prerelease.is_empty() and not l.prerelease.is_empty():
		return r.prerelease > l.prerelease
	
	return false

static func markdown_to_bbcode(md: String) -> String:
	var lines = md.split("\n")
	var result: Array[String] = []
	
	for line in lines:
		var trimmed = line.strip_edges()
		
		# Headings
		if trimmed.begins_with("### "):
			result.append("[b][color=#00eaff]%s[/color][/b]" % trimmed.substr(4).to_upper())
		elif trimmed.begins_with("## "):
			result.append("\n[b][color=#ffcc00]%s[/color][/b]" % trimmed.substr(3).to_upper())
		elif trimmed.begins_with("# "):
			result.append("\n[b][color=#00f6ff][font_size=16]%s[/font_size][/color][/b]" % trimmed.substr(2).to_upper())
		# Bullet points
		elif trimmed.begins_with("- ") or trimmed.begins_with("* "):
			var content = trimmed.substr(2)
			result.append("  [color=#00eaff]•[/color] %s" % _format_inline_markdown(content))
		elif trimmed.begins_with("> "):
			result.append("[color=#99bbdd][i]%s[/i][/color]" % trimmed.substr(2))
		else:
			result.append(_format_inline_markdown(line))
	
	return "\n".join(result)

static func _format_inline_markdown(text: String) -> String:
	# Replace **bold** with [b]bold[/b]
	var bold_regex = RegEx.new()
	bold_regex.compile("\\*\\*(.*?)\\*\\*")
	var res = bold_regex.sub(text, "[b]$1[/b]", true)
	
	# Replace `code` with [color=cyan]code[/color]
	var code_regex = RegEx.new()
	code_regex.compile("`(.*?)`")
	res = code_regex.sub(res, "[color=#00f0ff]$1[/color]", true)
	
	return res
