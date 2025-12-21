class_name PerfDisplayer
extends CanvasLayer

@export var ui_visible: bool = true : set = set_ui_visible, get = get_ui_visible
@export var update_hz: float = 4.0
@export var margin: Vector2 = Vector2(8, 8)
@export var font_size: int = 13
@export var debug_enabled: bool = false
@export var warn_fps: int = 50
@export var recover_fps: int = 57
@export var proc_warn_ms: float = 5.0
@export var phys_warn_ms: float = 2.0
@export var draws_warn: int = 3000
@export var log_cooldown_s: float = 2.0
@export var toggle_key: Key = KEY_F9
@export var toggle_debug_key: Key = KEY_F10

var _ui_visible: bool = true
var _acc: float = 0.0
var _low_fps_active: bool = false
var _last_log_s: float = 0.0

var _root: Control
var _label: Label

func set_ui_visible(v: bool) -> void:
	_ui_visible = v
	if _root:
		_root.visible = v

func get_ui_visible() -> bool:
	return _ui_visible

func _ready() -> void:
	layer = 128

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_label = Label.new()
	_label.position = margin
	_label.add_theme_font_size_override("font_size", font_size)
	_label.clip_text = false
	_root.add_child(_label)

	set_ui_visible(ui_visible)
	set_process_unhandled_input(true)

func _process(delta: float) -> void:
	if not _ui_visible:
		return

	_acc += delta
	var step: float = 1.0 / float(max(0.5, update_hz))
	if _acc < step:
		return
	_acc = 0.0
	_label.text = _build_text()

func _build_text() -> String:
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

	if debug_enabled and OS.is_debug_build():
		_debug_check(fps, t_proc, t_phys, draws, mem)

	return "FPS %d (%.2f ms)\nProcess %.3f ms\nPhysics %.3f ms\nPhys tick %d Hz (%.3f ms)\nMem %.1f / %.1f MiB\nObjects %d\nDraw calls %d" % \
		[fps, ms, t_proc, t_phys, phys_tps, phys_step_ms, mem, mem_max, objs, draws]

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
			set_ui_visible(not _ui_visible)
		elif event.keycode == toggle_debug_key:
			debug_enabled = not debug_enabled
			print("[PERF] debug_enabled=", debug_enabled)
