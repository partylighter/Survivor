class_name PerfDisplayer
extends CanvasLayer

@export var actif: bool = true
@export var debug_enabled: bool = false

var _ui_visible: bool = true
@export var ui_visible: bool = true:
	set(v):
		_ui_visible = v
		_apply_ui_visible()
	get:
		return _ui_visible

@export var update_hz: float = 4.0
@export var warn_fps: int = 50
@export var recover_fps: int = 57
@export var proc_warn_ms: float = 5.0
@export var phys_warn_ms: float = 2.0
@export var draws_warn: int = 3000
@export var log_cooldown_s: float = 2.0

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(8, 8)
@export var ui_largeur_min_px: float = 300.0
@export_range(8, 64, 1) var ui_taille_police: int = 13
@export var ui_couleur_fond: Color = Color(0, 0, 0, 0.55)
@export var ui_couleur_texte: Color = Color(1, 1, 1, 0.92)
@export_range(0, 64, 1) var ui_espace_lignes: int = 6

@export_group("Raccourci")
@export var toggle_key: Key = KEY_F9
@export var toggle_debug_key: Key = KEY_F10

var _acc: float = 0.0
var _low_fps_active: bool = false
var _last_log_s: float = 0.0

var _panel: Panel
var _margin: MarginContainer
var _root: VBoxContainer
var _stylebox: StyleBoxFlat
var _title: Label
var _sub: Label
var _grid: GridContainer
var _rows: Dictionary = {}
var _cache: Dictionary = {}

func _ready() -> void:
	layer = 128
	_ui_visible = ui_visible
	_creer_ui()
	_appliquer_style()
	_apply_ui_visible()
	set_process_unhandled_input(true)

func _apply_ui_visible() -> void:
	visible = _ui_visible
	if _panel != null:
		_panel.visible = _ui_visible
	set_process(_ui_visible and actif)

func _creer_ui() -> void:
	_panel = Panel.new()
	add_child(_panel)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(ui_largeur_min_px, 0.0)

	_margin = MarginContainer.new()
	_panel.add_child(_margin)
	_margin.add_theme_constant_override("margin_left", 10)
	_margin.add_theme_constant_override("margin_top", 10)
	_margin.add_theme_constant_override("margin_right", 10)
	_margin.add_theme_constant_override("margin_bottom", 10)

	_root = VBoxContainer.new()
	_margin.add_child(_root)
	_root.add_theme_constant_override("separation", ui_espace_lignes)

	var header := VBoxContainer.new()
	_root.add_child(header)
	header.add_theme_constant_override("separation", 2)

	_title = Label.new()
	_sub = Label.new()
	header.add_child(_title)
	header.add_child(_sub)

	_root.add_child(HSeparator.new())

	_grid = GridContainer.new()
	_grid.columns = 2
	_root.add_child(_grid)

	_add_row("FPS", "—")
	_add_row("Frame", "—")
	_add_row("Process", "—")
	_add_row("Physics", "—")
	_add_row("Phys tick", "—")
	_add_row("Mem", "—")
	_add_row("Objects", "—")
	_add_row("Draw calls", "—")

func _add_row(k: String, v: String) -> void:
	var lk := Label.new()
	var lv := Label.new()
	lk.text = k
	lv.text = v
	lk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_grid.add_child(lk)
	_grid.add_child(lv)
	_rows[k] = lv

func _appliquer_style() -> void:
	if _stylebox == null:
		_stylebox = StyleBoxFlat.new()

	_stylebox.bg_color = ui_couleur_fond
	_stylebox.border_color = Color(1, 1, 1, 0.22)
	_stylebox.border_width_top = 1
	_stylebox.border_width_bottom = 1
	_stylebox.border_width_left = 1
	_stylebox.border_width_right = 1
	_stylebox.corner_radius_top_left = 8
	_stylebox.corner_radius_top_right = 8
	_stylebox.corner_radius_bottom_left = 8
	_stylebox.corner_radius_bottom_right = 8
	_stylebox.shadow_color = Color(0, 0, 0, 0.35)
	_stylebox.shadow_size = 6

	_panel.add_theme_stylebox_override("panel", _stylebox)

	_title.text = "PERF"
	_title.add_theme_font_size_override("font_size", ui_taille_police + 3)
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))

	_sub.text = "F9 UI | F10 debug"
	_sub.add_theme_font_size_override("font_size", max(8, ui_taille_police - 2))
	_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))

	for c in _grid.get_children():
		if c is Label:
			var l := c as Label
			l.add_theme_font_size_override("font_size", ui_taille_police)
			l.add_theme_color_override("font_color", ui_couleur_texte)

func _set_val(k: String, v: String) -> void:
	if _cache.get(k, "") == v:
		return
	_cache[k] = v
	var lab := _rows.get(k, null) as Label
	if lab != null:
		lab.text = v

func _process(delta: float) -> void:
	if not _ui_visible or not actif or _panel == null or not _panel.visible:
		return

	_panel.position = ui_position

	_acc += delta
	var step: float = 1.0 / float(max(0.5, update_hz))
	if _acc < step:
		return
	_acc = 0.0

	var fps: int = int(Engine.get_frames_per_second())
	var ms: float = 1000.0 / float(max(1.0, float(fps)))

	var t_proc: float = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var t_phys: float = float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0

	var mem: float = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	var mem_max: float = float(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)) / 1048576.0

	var objs: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	var phys_tps: int = Engine.physics_ticks_per_second
	var phys_step_ms: float = 1000.0 / float(max(1, phys_tps))

	_set_val("FPS", str(fps))
	_set_val("Frame", "%.2f ms" % ms)
	_set_val("Process", "%.3f ms" % t_proc)
	_set_val("Physics", "%.3f ms" % t_phys)
	_set_val("Phys tick", "%d Hz (%.3f ms)" % [phys_tps, phys_step_ms])
	_set_val("Mem", "%.1f / %.1f MiB" % [mem, mem_max])
	_set_val("Objects", str(objs))
	_set_val("Draw calls", str(draws))

	if debug_enabled and OS.is_debug_build():
		_debug_check(fps, t_proc, t_phys, draws, mem)

func _debug_check(fps: int, t_proc: float, t_phys: float, draws: int, mem_mb: float) -> void:
	var now_s: float = float(Time.get_ticks_msec()) / 1000.0
	var can_log: bool = now_s - _last_log_s >= log_cooldown_s

	if fps < warn_fps and (not _low_fps_active or can_log):
		_low_fps_active = true
		_last_log_s = now_s
		print("[PERF] low FPS=", fps, " proc_ms=", "%.3f" % t_proc, " phys_ms=", "%.3f" % t_phys, " draws=", draws, " mem=", "%.1f MB" % mem_mb)
	elif fps >= recover_fps and _low_fps_active:
		_low_fps_active = false
		_last_log_s = now_s
		print("[PERF] recovered FPS=", fps)
	elif can_log and (t_proc > proc_warn_ms or t_phys > phys_warn_ms or draws > draws_warn):
		_last_log_s = now_s
		print("[PERF] spike proc_ms=", "%.3f" % t_proc, " phys_ms=", "%.3f" % t_phys, " draws=", draws)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			ui_visible = not ui_visible
		elif event.keycode == toggle_debug_key:
			debug_enabled = not debug_enabled
			print("[PERF] debug_enabled=", debug_enabled)
