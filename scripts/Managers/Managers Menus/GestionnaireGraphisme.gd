extends Node

const CONFIG_PATH := "user://display.cfg"

const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const DEFAULT_FULLSCREEN := false

var resolutions: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var resolution_index: int = 0
var fullscreen: bool = DEFAULT_FULLSCREEN

var _preview_res_index: int = 0
var _preview_fullscreen: bool = DEFAULT_FULLSCREEN

func _ready() -> void:
	resolution_index = _get_default_res_index()
	_preview_res_index = resolution_index
	_preview_fullscreen = fullscreen
	load_settings()
	_preview_res_index = resolution_index
	_preview_fullscreen = fullscreen
	apply_current()

func cycle_resolution_preview(step: int = 1) -> void:
	if resolutions.is_empty():
		return
	_preview_res_index = wrapi(_preview_res_index + step, 0, resolutions.size())

func toggle_fullscreen_preview() -> void:
	_preview_fullscreen = not _preview_fullscreen

func get_preview_resolution() -> Vector2i:
	if resolutions.is_empty():
		return DEFAULT_RESOLUTION
	_preview_res_index = clampi(_preview_res_index, 0, resolutions.size() - 1)
	return resolutions[_preview_res_index]

func get_preview_fullscreen() -> bool:
	return _preview_fullscreen

func has_pending_changes() -> bool:
	return _preview_res_index != resolution_index or _preview_fullscreen != fullscreen

func apply_and_save() -> void:
	resolution_index = _preview_res_index
	fullscreen = _preview_fullscreen
	apply_current()
	save_settings()

func reset_defaults() -> void:
	_preview_res_index = _get_default_res_index()
	_preview_fullscreen = DEFAULT_FULLSCREEN

func cancel_preview() -> void:
	_preview_res_index = resolution_index
	_preview_fullscreen = fullscreen

func apply_current() -> void:
	call_deferred("_apply_deferred")

func _apply_deferred() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var r := get_current_resolution()
		DisplayServer.window_set_size(r)
		DisplayServer.window_set_position((DisplayServer.screen_get_size() - r) / 2)

func get_current_resolution() -> Vector2i:
	if resolutions.is_empty():
		return DEFAULT_RESOLUTION
	resolution_index = clampi(resolution_index, 0, resolutions.size() - 1)
	return resolutions[resolution_index]

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "resolution_index", resolution_index)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(CONFIG_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		_guess_resolution_index_from_window()
		fullscreen = DEFAULT_FULLSCREEN
		return

	resolution_index = int(cfg.get_value("display", "resolution_index", _get_default_res_index()))
	fullscreen = bool(cfg.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))
	resolution_index = clampi(resolution_index, 0, max(resolutions.size() - 1, 0))

func _guess_resolution_index_from_window() -> void:
	var size := DisplayServer.window_get_size()
	for i in range(resolutions.size()):
		if resolutions[i] == size:
			resolution_index = i
			return
	resolution_index = _get_default_res_index()

func _get_default_res_index() -> int:
	if resolutions.is_empty():
		return 0
	for i in range(resolutions.size()):
		if resolutions[i] == DEFAULT_RESOLUTION:
			return i
	return 0
