extends Control

## UpdateDialog: In-game modal dialog for Project Vanguard updates.
## Displays patch notes, streamed progress bar, and handles the one-click restart flow.

@onready var modal_panel: PanelContainer = %ModalPanel
@onready var version_label: Label = %VersionLabel
@onready var size_label: Label = %SizeLabel
@onready var changelog_view: RichTextLabel = %ChangelogView
@onready var progress_bar: ProgressBar = %DownloadProgressBar
@onready var progress_label: Label = %ProgressLabel
@onready var status_label: Label = %StatusLabel

@onready var download_btn: Button = %DownloadBtn
@onready var restart_btn: Button = %RestartBtn
@onready var not_now_btn: Button = %NotNowBtn

func _ready() -> void:
	hide()
	
	download_btn.pressed.connect(_on_download_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	not_now_btn.pressed.connect(_on_not_now_pressed)
	
	if is_inside_tree():
		var updater = get_node_or_null("/root/Updater")
		if updater:
			updater.download_progress.connect(_on_download_progress)
			updater.update_ready.connect(_on_update_ready)
			updater.update_error.connect(_on_update_error)

func _ensure_references() -> void:
	if not version_label:
		version_label = find_child("VersionLabel", true, false)
	if not size_label:
		size_label = find_child("SizeLabel", true, false)
	if not changelog_view:
		changelog_view = find_child("ChangelogView", true, false)
	if not progress_bar:
		progress_bar = find_child("DownloadProgressBar", true, false)
	if not progress_label:
		progress_label = find_child("ProgressLabel", true, false)
	if not status_label:
		status_label = find_child("StatusLabel", true, false)
	if not download_btn:
		download_btn = find_child("DownloadBtn", true, false)
	if not restart_btn:
		restart_btn = find_child("RestartBtn", true, false)
	if not not_now_btn:
		not_now_btn = find_child("NotNowBtn", true, false)

func show_update_prompt(custom_cur: String = "", custom_new: String = "", custom_notes: String = "", custom_size: int = -1) -> void:
	_ensure_references()
	var updater = get_node_or_null("/root/Updater") if is_inside_tree() else null
	
	var cur_ver = custom_cur if not custom_cur.is_empty() else (updater.current_version if updater else "0.7.0")
	var new_ver = custom_new if not custom_new.is_empty() else (updater.available_version if updater else "0.8.0")
	var notes = custom_notes if not custom_notes.is_empty() else (updater.changelog_text if updater else "Squadron avionics firmware ready for installation.")
	var size = custom_size if custom_size >= 0 else (updater.asset_size_bytes if updater else 0)
	
	if version_label:
		version_label.text = "SORTIE AVIONICS UPGRADE // %s  ➔  %s" % [cur_ver, new_ver]
	
	if size > 0:
		var mb = size / (1024.0 * 1024.0)
		if size_label:
			size_label.text = "PACKAGE SIZE: %.1f MB" % mb
			size_label.visible = true
	elif size_label:
		size_label.visible = false
	
	# Format changelog to BBCode
	var bb = ""
	var UpdaterScript = load("res://updater.gd")
	if UpdaterScript and UpdaterScript.has_method("markdown_to_bbcode"):
		bb = UpdaterScript.markdown_to_bbcode(notes)
	else:
		bb = notes
	changelog_view.text = bb
	
	# Initial UI state
	progress_bar.value = 0
	progress_bar.visible = false
	progress_label.visible = false
	status_label.text = "READY FOR DOWNLOAD"
	status_label.add_theme_color_override("font_color", Color(0, 0.9, 1, 0.9))
	
	download_btn.visible = true
	download_btn.disabled = false
	download_btn.text = "[ DOWNLOAD UPDATE ]"
	
	restart_btn.visible = false
	not_now_btn.visible = true
	
	show()

func _on_download_pressed() -> void:
	var updater = get_node_or_null("/root/Updater")
	if not updater:
		return
	
	download_btn.disabled = true
	download_btn.text = "[ DOWNLOADING... ]"
	progress_bar.visible = true
	progress_label.visible = true
	status_label.text = "STREAMING REPO BINARY..."
	status_label.add_theme_color_override("font_color", Color(1, 0.84, 0, 0.95))
	
	updater.start_download()

func _on_download_progress(pct: float, downloaded: int, total: int) -> void:
	progress_bar.value = pct
	var dl_mb = downloaded / (1024.0 * 1024.0)
	var tot_mb = total / (1024.0 * 1024.0)
	progress_label.text = "%.1f / %.1f MB (%.1f%%)" % [dl_mb, tot_mb, pct]

func _on_update_ready() -> void:
	progress_bar.value = 100
	progress_label.text = "EXTRACTION COMPLETE // READY"
	status_label.text = "RESTART REQUIRED TO FINALIZE INSTALLATION"
	status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 0.95))
	
	download_btn.visible = false
	restart_btn.visible = true
	not_now_btn.visible = true
	not_now_btn.text = "[ LATER ]"

func _on_update_error(message: String) -> void:
	download_btn.disabled = false
	download_btn.text = "[ RETRY DOWNLOAD ]"
	status_label.text = "ERROR: " + message
	status_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))

func _on_restart_pressed() -> void:
	status_label.text = "LAUNCHING UPDATER SCRIPT..."
	var updater = get_node_or_null("/root/Updater")
	if updater:
		updater.apply_update_and_restart()

func _on_not_now_pressed() -> void:
	var updater = get_node_or_null("/root/Updater")
	if updater:
		updater.has_dismissed_prompt = true
	hide()
