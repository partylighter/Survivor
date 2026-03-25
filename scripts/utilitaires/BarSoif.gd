extends Node
class_name BarSoif

enum DebugLevel { OFF, ERREURS, ETATS, VERBEUX }

@export_node_path("Node2D") var chemin_hote: NodePath
@export_node_path("HScrollBar") var chemin_bar: NodePath
@export_node_path("Node") var chemin_soif: NodePath

@export var offset: Vector2 = Vector2(0, 0)
@export_range(10.0, 3000.0, 1.0) var vitesse_px_s: float = 450.0
@export_range(0.0, 1.0, 0.01) var valeur_smooth: float = 0.08
@export var toujours_visible: bool = false
@export_range(0.0, 500.0, 1.0) var distance_max_px: float = 60.0
@export var frames_activation: int = 3

@export_group("Float (idle/move)")
@export var float_actif: bool = true
@export var float_idle_amp_px: Vector2 = Vector2(2.0, 7.0)
@export var float_move_amp_px: Vector2 = Vector2(1.0, 3.0)
@export_range(0.0, 6.0, 0.05) var float_freq_hz: float = 1.2
@export_range(0.0, 3.0, 0.05) var float_move_freq_mul: float = 1.55
@export_range(1.0, 2000.0, 1.0) var speed_full_px_s: float = 220.0
@export_range(0.0, 40.0, 0.5) var inertia_px: float = 10.0
@export_range(0.0, 40.0, 0.5) var inertia_up_px: float = 4.0
@export_range(0.01, 0.6, 0.01) var follow_smooth_idle_s: float = 0.18
@export_range(0.01, 0.6, 0.01) var follow_smooth_move_s: float = 0.07
@export_range(0.0, 1.0, 0.01) var speed_smooth: float = 0.25

@export_group("Shake")
@export var shake_actif: bool = false
@export_range(0.0, 40.0, 0.5) var shake_force_px: float = 8.0
@export_range(0.01, 0.3, 0.01) var shake_duree_s: float = 0.12
@export_range(0.0, 60.0, 1.0) var shake_frequence_hz: float = 28.0

@export_group("Stabilité")
@export var update_en_physics: bool = true
@export var snap_pixels: bool = true

@export var debug_bar_soif: bool = false
@export var debug_level: DebugLevel = DebugLevel.ETATS
@export_range(0.0, 5.0, 0.05) var debug_interval_s: float = 0.35

var _shake_t: float = 0.0
var _shake_seed: float = 0.0

var _hote: Node2D
var _bar: HScrollBar
var _soif: Soif

var _soif_affichee: float = 0.0

var _mort: bool = false
var _actif_ui: bool = false
var _dead_lock: bool = false
var _frame_activation: int = 0

var _dbg_last_time: Dictionary = {}
var _dbg_once: Dictionary = {}

var _follow_pos: Vector2 = Vector2.ZERO
var _follow_vel: Vector2 = Vector2.ZERO
var _prev_hote_pos: Vector2 = Vector2.ZERO
var _speed_smoothed: float = 0.0
var _phase: float = 0.0
var _phase2: float = 0.0

func _ts() -> float:
	return Time.get_ticks_msec() * 0.001

func _id() -> String:
	return "%s#%s" % [name, str(get_instance_id())]

func _can_log(key: String) -> bool:
	if debug_interval_s <= 0.0:
		return true
	var now: float = _ts()
	var last: float = float(_dbg_last_time.get(key, -1e20))
	if now - last < debug_interval_s:
		return false
	_dbg_last_time[key] = now
	return true

func _log(lvl: int, msg: String, key: String = "") -> void:
	if not debug_bar_soif:
		return
	if int(debug_level) < lvl:
		return
	if key != "" and not _can_log(key):
		return
	print("[BarSoif][%s] %s" % [_id(), msg])

func _once(tag: String, msg: String, lvl: int = DebugLevel.ERREURS) -> void:
	if not debug_bar_soif:
		return
	if _dbg_once.has(tag):
		return
	_dbg_once[tag] = true
	_log(lvl, msg, "")

func _smooth_damp_vec2(current: Vector2, target: Vector2, smooth_time: float, max_speed: float, delta: float) -> Vector2:
	smooth_time = maxf(0.0001, smooth_time)

	var omega: float = 2.0 / smooth_time
	var x: float = omega * delta
	var expv: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)

	var change: Vector2 = current - target
	var original_to: Vector2 = target

	var max_change: float = max_speed * smooth_time
	if max_change > 0.0:
		change = change.limit_length(max_change)

	target = current - change
	var temp: Vector2 = (_follow_vel + omega * change) * delta
	_follow_vel = (_follow_vel - omega * temp) * expv
	var output: Vector2 = target + (change + temp) * expv

	if (original_to - current).dot(output - original_to) > 0.0:
		output = original_to
		_follow_vel = Vector2.ZERO

	return output

func _ready() -> void:
	_hote = get_node_or_null(chemin_hote) as Node2D
	_soif = get_node_or_null(chemin_soif) as Soif

	if _soif:
		_soif.connect("changed", Callable(self, "_on_soif_changed"))
		_soif.connect("empty", Callable(self, "_on_soif_empty"))

	if _hote == null:
		_once("no_hote", "chemin_hote invalide: %s" % str(chemin_hote))
	if _soif == null:
		_once("no_soif", "chemin_soif invalide: %s" % str(chemin_soif))

	var bar_node := get_node_or_null(chemin_bar)
	if bar_node is HScrollBar:
		_bar = bar_node as HScrollBar
	else:
		var desc: String = "null" if bar_node == null else String(bar_node.get_class())
		push_warning("chemin_bar invalide ou type ≠ HScrollBar: %s" % desc)
		_once("no_bar", "chemin_bar invalide ou type ≠ HScrollBar: %s (%s)" % [str(chemin_bar), desc])

	if _bar:
		_bar.top_level = true
		_bar.focus_mode = Control.FOCUS_NONE
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.step = 0.0
		_bar.z_index = 1

	if _soif and _bar:
		var soif_init: float = _soif.soif
		var max_soif_init: float = _soif.soif_max
		_soif_affichee = soif_init

		_bar.min_value = 0.0
		_bar.max_value = maxf(1.0, max_soif_init)
		_bar.value = 0.0
		_bar.page = clampf(soif_init, 0.0, _bar.max_value)

	if _hote and _bar:
		var pos: Vector2 = _hote.global_position + offset
		_follow_pos = pos
		_prev_hote_pos = _hote.global_position
		_bar.global_position = pos.snapped(Vector2.ONE) if snap_pixels else pos

	_phase = float(int(get_instance_id() % 10000)) / 10000.0 * TAU
	_phase2 = _phase * 1.37 + 0.9

	if _hote:
		if _hote.has_signal("mort"):
			_hote.connect("mort", Callable(self, "_on_hote_mort"))
		else:
			_log(DebugLevel.VERBEUX, "Hote n'a pas le signal 'mort'", "sig_mort")

		if _hote.has_signal("reapparu"):
			_hote.connect("reapparu", Callable(self, "_on_hote_reapparu"))
		else:
			_log(DebugLevel.VERBEUX, "Hote n'a pas le signal 'reapparu'", "sig_reapparu")

	set_physics_process(update_en_physics)
	set_process(not update_en_physics)

	var hote_s: String = "null"
	if _hote:
		hote_s = str(_hote.name)

	var bar_s: String = "null"
	if _bar:
		bar_s = str(_bar.name)

	var soif_s: String = "null"
	if _soif:
		soif_s = String(_soif.get_class())

	_log(DebugLevel.ETATS, "Ready: hote=%s soif=%s bar=%s" % [hote_s, soif_s, bar_s], "ready")

	if _soif and _bar and _hote:
		_refresh_activation(true)
	else:
		_actif_ui = false

func _on_soif_changed(_valeur_actuelle: float, _valeur_max: float) -> void:
	if shake_actif:
		_shake_t = shake_duree_s
		_shake_seed = float(Time.get_ticks_msec()) * 0.001

func _on_soif_empty() -> void:
	if shake_actif:
		_shake_t = shake_duree_s
		_shake_seed = float(Time.get_ticks_msec()) * 0.001

func _physics_process(delta: float) -> void:
	if update_en_physics:
		_tick(delta)

func _process(delta: float) -> void:
	if not update_en_physics:
		_tick(delta)

func _tick(delta: float) -> void:
	if _hote == null or _bar == null or _soif == null:
		return

	if _frame_activation == 0:
		_refresh_activation(false)
	_frame_activation = (_frame_activation + 1) % max(frames_activation, 1)

	if not _actif_ui or _dead_lock:
		return

	var hpos: Vector2 = _hote.global_position
	var v: Vector2 = Vector2.ZERO
	if delta > 0.0:
		v = (hpos - _prev_hote_pos) / delta
	_prev_hote_pos = hpos

	var speed: float = v.length()
	var sp_alpha: float = 1.0 - pow(1.0 - clampf(speed_smooth, 0.0, 1.0), 60.0 * delta)
	_speed_smoothed = lerpf(_speed_smoothed, speed, sp_alpha)

	var speed_ratio: float = 0.0
	if speed_full_px_s > 0.0:
		speed_ratio = clampf(_speed_smoothed / speed_full_px_s, 0.0, 1.0)

	var t: float = _ts()

	var float_off: Vector2 = Vector2.ZERO
	if float_actif:
		var amp: Vector2 = float_idle_amp_px.lerp(float_move_amp_px, speed_ratio)
		var freq: float = float_freq_hz * lerpf(1.0, float_move_freq_mul, speed_ratio)
		float_off = Vector2(
			sin(t * TAU * freq + _phase) * amp.x,
			sin(t * TAU * freq * 0.92 + _phase2) * amp.y
		)

	var inertia_off: Vector2 = Vector2.ZERO
	if inertia_px > 0.0 and _speed_smoothed > 0.1:
		var denom: float = maxf(_speed_smoothed, 0.0001)
		var dir: Vector2 = v / denom
		inertia_off = (-dir * inertia_px * speed_ratio) + Vector2(0.0, -inertia_up_px * speed_ratio)

	var cible: Vector2 = hpos + offset + float_off + inertia_off

	var smooth_time: float = lerpf(follow_smooth_idle_s, follow_smooth_move_s, speed_ratio)
	_follow_pos = _smooth_damp_vec2(_follow_pos, cible, smooth_time, vitesse_px_s, delta)

	var ecart: Vector2 = _follow_pos - cible
	var dist: float = ecart.length()
	if dist > distance_max_px and dist > 0.0:
		_follow_pos = cible + ecart * (distance_max_px / dist)
		_follow_vel = Vector2.ZERO

	var shake_off: Vector2 = Vector2.ZERO
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - delta, 0.0)
		var k: float = _shake_t / maxf(shake_duree_s, 0.0001)
		var amp2: float = shake_force_px * k
		shake_off = Vector2(
			sin((t + _shake_seed) * TAU * shake_frequence_hz) * amp2,
			cos((t + _shake_seed) * TAU * shake_frequence_hz * 0.93) * amp2
		)

	var p: Vector2 = _follow_pos + shake_off
	if snap_pixels:
		p = p.snapped(Vector2.ONE)

	_bar.global_position = p

	var soif_reelle: float = _soif.soif
	var max_soif: float = _soif.soif_max

	var a: float = 1.0 - pow(1.0 - valeur_smooth, 60.0 * delta)
	_soif_affichee = lerpf(_soif_affichee, soif_reelle, a)

	_bar.max_value = maxf(1.0, max_soif)
	_bar.page = clampf(_soif_affichee, 0.0, _bar.max_value)
	_bar.value = 0.0

func _refresh_activation(force_show: bool) -> void:
	if _bar == null or _hote == null or _soif == null:
		_actif_ui = false
		return

	if _mort:
		if _actif_ui:
			_log(DebugLevel.ETATS, "Hide UI (mort)", "hide_mort")
		_actif_ui = false
		_bar.hide()
		return

	var hote_actif: bool = _hote.is_physics_processing()
	var soif_reelle: float = _soif.soif

	var doit_montrer: bool
	if toujours_visible:
		doit_montrer = true
	else:
		doit_montrer = force_show or (soif_reelle < _soif.soif_max and hote_actif)

	if doit_montrer:
		if not _actif_ui:
			_soif_affichee = soif_reelle
			_bar.max_value = maxf(1.0, float(_soif.soif_max))
			_bar.page = clampf(_soif_affichee, 0.0, _bar.max_value)
			_bar.value = 0.0

			var pos: Vector2 = _hote.global_position + offset
			_follow_pos = pos
			_follow_vel = Vector2.ZERO
			_prev_hote_pos = _hote.global_position
			_speed_smoothed = 0.0

			var p: Vector2 = pos.snapped(Vector2.ONE) if snap_pixels else pos
			_bar.global_position = p

			_log(DebugLevel.ETATS, "Show UI (soif=%.1f max=%.1f active=%s)" % [soif_reelle, _soif.soif_max, str(hote_actif)], "show")

		_bar.show()
		_actif_ui = true
	else:
		if _actif_ui:
			_log(DebugLevel.ETATS, "Hide UI (soif=%.1f max=%.1f active=%s)" % [soif_reelle, _soif.soif_max, str(hote_actif)], "hide")
			_bar.hide()
		_actif_ui = false

func _on_hote_mort() -> void:
	_mort = true
	_dead_lock = true
	_actif_ui = false
	if _bar:
		_bar.hide()
	_log(DebugLevel.ETATS, "Signal mort -> lock UI", "sig_mort")

func _on_hote_reapparu() -> void:
	if not _dead_lock:
		_log(DebugLevel.VERBEUX, "Signal reapparu ignoré (dead_lock=false)", "sig_reap")
		return

	_dead_lock = false
	_mort = false

	if _soif and _bar:
		var soif_reelle: float = _soif.soif
		var max_soif_now: float = _soif.soif_max
		_soif_affichee = soif_reelle
		_bar.max_value = maxf(1.0, max_soif_now)
		_bar.page = clampf(_soif_affichee, 0.0, _bar.max_value)
		_bar.value = 0.0

	if _bar and _hote:
		var pos: Vector2 = _hote.global_position + offset
		_follow_pos = pos
		_follow_vel = Vector2.ZERO
		_prev_hote_pos = _hote.global_position
		_speed_smoothed = 0.0

		var p: Vector2 = pos.snapped(Vector2.ONE) if snap_pixels else pos
		_bar.global_position = p

	_actif_ui = false
	_refresh_activation(toujours_visible)
	_log(DebugLevel.ETATS, "Signal reapparu -> unlock UI", "sig_reap")
