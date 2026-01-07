extends Node

const CONFIG_PATH: String = "user://display.cfg"

const DEFAULT_RESOLUTION: Vector2i = Vector2i(1920, 1080)
const DEFAULT_FULLSCREEN: bool = true

const DECOR_MARGIN_PX: Vector2i = Vector2i(40, 90)
const MIN_WINDOW_PX: Vector2i = Vector2i(640, 360)

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
	fullscreen = DEFAULT_FULLSCREEN
	load_settings()
	_preview_res_index = resolution_index
	_preview_fullscreen = fullscreen
	_clamp_indices_for_current_screen()
	apply_current()

func cycle_resolution_preview(step: int = 1) -> void:
	if resolutions.is_empty():
		return

	var w := get_tree().root.get_window()
	var screen := w.current_screen

	if _preview_fullscreen:
		_preview_res_index = wrapi(_preview_res_index + step, 0, resolutions.size())
		return

	var allowed := _get_allowed_indices_for_screen(screen)
	var pos := allowed.find(_preview_res_index)
	if pos == -1:
		pos = 0
	pos = wrapi(pos + step, 0, allowed.size())
	_preview_res_index = allowed[pos]

func toggle_fullscreen_preview() -> void:
	_preview_fullscreen = not _preview_fullscreen
	if not _preview_fullscreen:
		var w := get_tree().root.get_window()
		_preview_res_index = _clamp_res_index_to_fit(w.current_screen, _preview_res_index)

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
	fullscreen = _preview_fullscreen

	var w := get_tree().root.get_window()
	if fullscreen:
		resolution_index = clampi(_preview_res_index, 0, max(resolutions.size() - 1, 0))
	else:
		resolution_index = _clamp_res_index_to_fit(w.current_screen, _preview_res_index)

	_preview_res_index = resolution_index

	apply_current()
	save_settings()

func reset_defaults() -> void:
	_preview_res_index = _get_default_res_index()
	_preview_fullscreen = DEFAULT_FULLSCREEN

func cancel_preview() -> void:
	_preview_res_index = resolution_index
	_preview_fullscreen = fullscreen

func is_using_defaults() -> bool:
	return resolution_index == _get_default_res_index() and fullscreen == DEFAULT_FULLSCREEN

func apply_current() -> void:
	call_deferred("_apply_deferred")

func apply_to_window(w: Window) -> void:
	if w == null:
		return

	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	var r := get_current_resolution()
	w.content_scale_size = r

	if fullscreen:
		if OS.has_feature("editor"):
			w.mode = Window.MODE_FULLSCREEN
		else:
			w.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		return

	w.mode = Window.MODE_WINDOWED

	var screen := w.current_screen
	var max_size := _get_max_window_size_for_screen(screen)
	var final_size := Vector2i(min(r.x, max_size.x), min(r.y, max_size.y))
	final_size.x = maxi(final_size.x, MIN_WINDOW_PX.x)
	final_size.y = maxi(final_size.y, MIN_WINDOW_PX.y)

	w.size = final_size
	w.move_to_center()

func _apply_deferred() -> void:
	var w: Window = get_tree().root.get_window()
	apply_to_window(w)

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
		resolution_index = _get_default_res_index()
		fullscreen = DEFAULT_FULLSCREEN
		return

	resolution_index = int(cfg.get_value("display", "resolution_index", _get_default_res_index()))
	fullscreen = bool(cfg.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))
	resolution_index = clampi(resolution_index, 0, max(resolutions.size() - 1, 0))

func _get_default_res_index() -> int:
	if resolutions.is_empty():
		return 0
	for i in range(resolutions.size()):
		if resolutions[i] == DEFAULT_RESOLUTION:
			return i
	return 0

func _get_max_window_size_for_screen(screen: int) -> Vector2i:
	var rect: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var size := rect.size
	if size.x <= 0 or size.y <= 0:
		size = DisplayServer.screen_get_size(screen)
	size -= DECOR_MARGIN_PX
	size.x = maxi(size.x, MIN_WINDOW_PX.x)
	size.y = maxi(size.y, MIN_WINDOW_PX.y)
	return size

func _get_allowed_indices_for_screen(screen: int) -> Array[int]:
	var max_size := _get_max_window_size_for_screen(screen)
	var out: Array[int] = []
	for i in range(resolutions.size()):
		var r := resolutions[i]
		if r.x <= max_size.x and r.y <= max_size.y:
			out.append(i)
	if out.is_empty():
		out.append(0)
	return out

func _clamp_res_index_to_fit(screen: int, idx: int) -> int:
	if resolutions.is_empty():
		return 0

	var max_size := _get_max_window_size_for_screen(screen)
	idx = clampi(idx, 0, resolutions.size() - 1)

	var desired := resolutions[idx]
	if desired.x <= max_size.x and desired.y <= max_size.y:
		return idx

	var best_under := -1
	for i in range(resolutions.size()):
		var r := resolutions[i]
		if r.x <= max_size.x and r.y <= max_size.y and i <= idx:
			best_under = i
	if best_under != -1:
		return best_under

	var best := -1
	for i in range(resolutions.size()):
		var r := resolutions[i]
		if r.x <= max_size.x and r.y <= max_size.y:
			best = i
	return 0 if best == -1 else best

func _clamp_indices_for_current_screen() -> void:
	var w := get_tree().root.get_window()
	if not fullscreen:
		resolution_index = _clamp_res_index_to_fit(w.current_screen, resolution_index)
	_preview_res_index = clampi(_preview_res_index, 0, max(resolutions.size() - 1, 0))
