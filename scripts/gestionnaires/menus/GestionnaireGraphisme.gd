extends Node

const CONFIG_PATH: String = "user://display.cfg"

const DEFAULT_RESOLUTION: Vector2i = Vector2i(1920, 1080)
const DEFAULT_FULLSCREEN: bool = true
const DEFAULT_GLOW_ACTIF: bool = true

const BASE_CANVAS_SIZE: Vector2i = Vector2i(1920, 1080)

const DECOR_MARGIN_PX: Vector2i = Vector2i(40, 90)
const MIN_WINDOW_PX: Vector2i = Vector2i(640, 360)

var resolutions: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
	Vector2i(640, 360),
	Vector2i(960, 540),
]

var resolution_index: int = 0
var fullscreen: bool = DEFAULT_FULLSCREEN
var glow_actif: bool = DEFAULT_GLOW_ACTIF

var _preview_res_index: int = 0
var _preview_fullscreen: bool = DEFAULT_FULLSCREEN
var _preview_glow_actif: bool = DEFAULT_GLOW_ACTIF
var _world_environment: WorldEnvironment
var _environment: Environment

func _ready() -> void:
	resolution_index = _get_default_res_index()
	fullscreen = DEFAULT_FULLSCREEN
	load_settings()
	_preview_res_index = resolution_index
	_preview_fullscreen = fullscreen
	_preview_glow_actif = glow_actif
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

func toggle_glow_preview() -> void:
	_preview_glow_actif = not _preview_glow_actif

func get_preview_resolution() -> Vector2i:
	if resolutions.is_empty():
		return DEFAULT_RESOLUTION
	_preview_res_index = clampi(_preview_res_index, 0, resolutions.size() - 1)
	return resolutions[_preview_res_index]

func get_preview_fullscreen() -> bool:
	return _preview_fullscreen

func get_preview_glow_actif() -> bool:
	return _preview_glow_actif

func has_pending_changes() -> bool:
	return _preview_res_index != resolution_index or _preview_fullscreen != fullscreen or _preview_glow_actif != glow_actif

func apply_and_save() -> void:
	fullscreen = _preview_fullscreen
	glow_actif = _preview_glow_actif

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
	_preview_glow_actif = DEFAULT_GLOW_ACTIF

func cancel_preview() -> void:
	_preview_res_index = resolution_index
	_preview_fullscreen = fullscreen
	_preview_glow_actif = glow_actif

func is_using_defaults() -> bool:
	return resolution_index == _get_default_res_index() and fullscreen == DEFAULT_FULLSCREEN and glow_actif == DEFAULT_GLOW_ACTIF

func apply_current() -> void:
	call_deferred("_apply_deferred")

func apply_to_window(w: Window) -> void:
	if w == null:
		return

	var r := get_current_resolution()

	w.content_scale_mode   = Window.CONTENT_SCALE_MODE_VIEWPORT
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	w.content_scale_size   = r

	if fullscreen:
		if OS.has_feature("editor"):
			w.mode = Window.MODE_FULLSCREEN
		else:
			w.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		return

	w.mode = Window.MODE_WINDOWED

	var screen    := w.current_screen
	var max_size  := _get_max_window_size_for_screen(screen)
	var final_size := Vector2i(min(r.x, max_size.x), min(r.y, max_size.y))
	final_size.x   = maxi(final_size.x, MIN_WINDOW_PX.x)
	final_size.y   = maxi(final_size.y, MIN_WINDOW_PX.y)

	w.size = final_size
	w.move_to_center()

func _apply_deferred() -> void:
	var w: Window = get_tree().root.get_window()
	apply_to_window(w)
	_apply_world_environment()

func get_current_resolution() -> Vector2i:
	if resolutions.is_empty():
		return DEFAULT_RESOLUTION
	resolution_index = clampi(resolution_index, 0, resolutions.size() - 1)
	return resolutions[resolution_index]

func save_settings() -> void:
	var cfg := ConfigFile.new()
	var r := get_current_resolution()
	cfg.set_value("display", "resolution_x", r.x)
	cfg.set_value("display", "resolution_y", r.y)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "glow_actif", glow_actif)
	cfg.save(CONFIG_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		resolution_index = _get_default_res_index()
		fullscreen = DEFAULT_FULLSCREEN
		return

	var rx: int = int(cfg.get_value("display", "resolution_x", DEFAULT_RESOLUTION.x))
	var ry: int = int(cfg.get_value("display", "resolution_y", DEFAULT_RESOLUTION.y))
	resolution_index = _find_resolution_index(Vector2i(rx, ry))
	fullscreen = bool(cfg.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))
	glow_actif = bool(cfg.get_value("display", "glow_actif", DEFAULT_GLOW_ACTIF))

func _apply_world_environment() -> void:
	if _world_environment == null or not is_instance_valid(_world_environment):
		_world_environment = WorldEnvironment.new()
		_world_environment.name = "WorldEnvironmentGlobal"
		get_tree().root.add_child(_world_environment)
	if _environment == null:
		_environment = _creer_environment_par_defaut()
	_world_environment.environment = _environment
	_environment.glow_enabled = glow_actif

func _creer_environment_par_defaut() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.99
	env.tonemap_white = 16.0
	env.glow_enabled = glow_actif
	env.set("glow_levels/1", 1.4)
	env.set("glow_levels/2", 1.2)
	env.set("glow_levels/7", 0.2)
	env.glow_intensity = 0.2
	env.glow_bloom = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.18
	return env

func _find_resolution_index(r: Vector2i) -> int:
	for i in range(resolutions.size()):
		if resolutions[i] == r:
			return i
	return _get_default_res_index()

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
