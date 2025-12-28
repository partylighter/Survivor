extends Node
class_name BarPV

enum DebugLevel { OFF, ERREURS, ETATS, VERBEUX }

@export_node_path("Node2D") var chemin_hote: NodePath
@export_node_path("HScrollBar") var chemin_bar: NodePath
@export_node_path("HScrollBar") var chemin_bar_overheal: NodePath
@export_node_path("Node") var chemin_sante: NodePath
@export_node_path("Node") var chemin_loot: NodePath

@export var offset: Vector2 = Vector2(0, 0)
@export_range(10.0, 1000.0, 1.0) var vitesse_px_s: float = 450.0
@export_range(0.0, 1.0, 0.01) var valeur_smooth: float = 0.08
@export var toujours_visible: bool = false
@export_range(0.0, 500.0, 1.0) var distance_max_px: float = 60.0
@export var frames_activation: int = 3

@export var debug_bar_pv: bool = false
@export var debug_level: DebugLevel = DebugLevel.ETATS
@export_range(0.0, 5.0, 0.05) var debug_interval_s: float = 0.35
@export_range(0.0, 10.0, 0.1) var debug_tol_pv: float = 0.25
@export_range(0.0, 10.0, 0.1) var debug_tol_overheal: float = 0.25

var _hote: Node2D
var _bar: HScrollBar
var _bar_overheal: HScrollBar
var _sante: Sante
var _loot: GestionnaireLoot

var _pv_affiche: float = 0.0

var _mort: bool = false
var _actif_ui: bool = false
var _dead_lock: bool = false
var _frame_activation: int = 0

var _dbg_last_time: Dictionary = {}
var _dbg_once: Dictionary = {}

var _dbg_prev_pv: float = INF
var _dbg_prev_max: float = INF
var _dbg_prev_over: float = INF
var _dbg_prev_actif: bool = false
var _dbg_prev_dead_lock: bool = false
var _dbg_prev_mort: bool = false
var _dbg_prev_over_visible: bool = false
var _dbg_prev_over_width: float = INF

func _ts() -> float:
	return Time.get_ticks_msec() * 0.001

func _id() -> String:
	return "%s#%s" % [name, str(get_instance_id())]

func _can_log(key: String) -> bool:
	if debug_interval_s <= 0.0:
		return true
	var now := _ts()
	var last: float = float(_dbg_last_time.get(key, -1e20))
	if now - last < debug_interval_s:
		return false
	_dbg_last_time[key] = now
	return true

func _log(lvl: int, msg: String, key: String = "") -> void:
	if not debug_bar_pv:
		return
	if int(debug_level) < lvl:
		return
	if key != "" and not _can_log(key):
		return
	print("[BarPV][%s] %s" % [_id(), msg])

func _once(tag: String, msg: String, lvl: int = DebugLevel.ERREURS) -> void:
	if not debug_bar_pv:
		return
	if _dbg_once.has(tag):
		return
	_dbg_once[tag] = true
	_log(lvl, msg, "")

func _diff(a: float, b: float, tol: float) -> bool:
	return abs(a - b) > tol

func _ready() -> void:
	_hote = get_node_or_null(chemin_hote) as Node2D
	_sante = get_node_or_null(chemin_sante) as Sante
	_loot = get_node_or_null(chemin_loot) as GestionnaireLoot

	if _hote == null:
		_once("no_hote", "chemin_hote invalide: %s" % str(chemin_hote))
	if _sante == null:
		_once("no_sante", "chemin_sante invalide: %s" % str(chemin_sante))
	if _loot == null:
		_log(DebugLevel.VERBEUX, "chemin_loot null ou invalide: %s" % str(chemin_loot), "loot")

	var bar_node := get_node_or_null(chemin_bar)
	if bar_node is HScrollBar:
		_bar = bar_node as HScrollBar
	else:
		var desc := "null" if bar_node == null else String(bar_node.get_class())
		push_warning("chemin_bar invalide ou type ≠ HScrollBar: %s" % desc)
		_once("no_bar", "chemin_bar invalide ou type ≠ HScrollBar: %s (%s)" % [str(chemin_bar), desc])

	var bar_over_node := get_node_or_null(chemin_bar_overheal)
	if bar_over_node is HScrollBar:
		_bar_overheal = bar_over_node as HScrollBar
	else:
		var desc2 := "null" if bar_over_node == null else String(bar_over_node.get_class())
		push_warning("chemin_bar_overheal invalide ou type ≠ HScrollBar: %s" % desc2)
		_log(DebugLevel.ERREURS, "chemin_bar_overheal invalide ou type ≠ HScrollBar: %s (%s)" % [str(chemin_bar_overheal), desc2], "overheal_ref")

	if _bar:
		_bar.top_level = true
		_bar.focus_mode = Control.FOCUS_NONE
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.step = 0.0
		_bar.z_index = 1

	if _bar_overheal:
		_bar_overheal.top_level = true
		_bar_overheal.focus_mode = Control.FOCUS_NONE
		_bar_overheal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar_overheal.step = 0.0
		_bar_overheal.z_index = 0

	if _sante and _bar:
		var pv_init: float = _sante.pv
		var max_pv_init: float = _sante.max_pv
		_pv_affiche = pv_init

		_bar.min_value = 0.0
		_bar.max_value = max(1.0, max_pv_init)
		_bar.value = 0.0
		_bar.page = clampf(pv_init, 0.0, _bar.max_value)

	if _bar_overheal:
		_bar_overheal.size.x = 0.0
		_bar_overheal.size.y = _bar.size.y if _bar else _bar_overheal.size.y
		_bar_overheal.min_value = 0.0
		_bar_overheal.max_value = 1.0
		_bar_overheal.value = 0.0
		_bar_overheal.page = 1.0
		_bar_overheal.hide()
		_dbg_prev_over_visible = false
		_dbg_prev_over_width = 0.0

	if _hote and _bar:
		var pos := _hote.global_position + offset
		_bar.global_position = pos
		if _bar_overheal:
			_bar_overheal.global_position = pos + Vector2(_bar.size.x, 0.0)

	if _hote:
		if _hote.has_signal("mort"):
			_hote.connect("mort", Callable(self, "_on_hote_mort"))
		else:
			_log(DebugLevel.VERBEUX, "Hote n'a pas le signal 'mort'", "sig_mort")

		if _hote.has_signal("reapparu"):
			_hote.connect("reapparu", Callable(self, "_on_hote_reapparu"))
		else:
			_log(DebugLevel.VERBEUX, "Hote n'a pas le signal 'reapparu'", "sig_reapparu")

	var hote_s := "null"
	if _hote:
		hote_s = str(_hote.name)

	var bar_s := "null"
	if _bar:
		bar_s = str(_bar.name)

	var over_s := "null"
	if _bar_overheal:
		over_s = str(_bar_overheal.name)

	var sante_s := "null"
	if _sante:
		sante_s = String(_sante.get_class())

	_log(DebugLevel.ETATS, "Ready: hote=%s sante=%s bar=%s overheal_bar=%s" % [hote_s, sante_s, bar_s, over_s], "ready")

	if _sante and _bar and _hote:
		_refresh_activation(true)
	else:
		_actif_ui = false

func _process(delta: float) -> void:
	if _hote == null or _bar == null or _sante == null:
		return

	var pv_reel: float = _sante.pv
	var max_pv: float = _sante.max_pv
	var overheal: float = _sante.get_overheal()

	if _diff(pv_reel, _dbg_prev_pv, debug_tol_pv) or _diff(max_pv, _dbg_prev_max, debug_tol_pv):
		_dbg_prev_pv = pv_reel
		_dbg_prev_max = max_pv
		_log(DebugLevel.VERBEUX, "PV change: pv=%.2f max=%.2f" % [pv_reel, max_pv], "pv")

	if _diff(overheal, _dbg_prev_over, debug_tol_overheal):
		_dbg_prev_over = overheal
		_log(DebugLevel.ETATS, "Overheal: %.2f" % overheal, "over")

	if _frame_activation == 0:
		_refresh_activation(false)
	_frame_activation = (_frame_activation + 1) % max(frames_activation, 1)

	if _dbg_prev_mort != _mort or _dbg_prev_dead_lock != _dead_lock:
		_dbg_prev_mort = _mort
		_dbg_prev_dead_lock = _dead_lock
		_log(DebugLevel.ETATS, "Etat: mort=%s dead_lock=%s" % [str(_mort), str(_dead_lock)], "etat")

	if _dbg_prev_actif != _actif_ui:
		_dbg_prev_actif = _actif_ui
		_log(DebugLevel.ETATS, "UI actif=%s" % str(_actif_ui), "ui_actif")

	if not _actif_ui or _dead_lock:
		return

	var cible: Vector2 = _hote.global_position + offset
	var tentative: Vector2 = _bar.global_position.move_toward(cible, vitesse_px_s * delta)
	var ecart: Vector2 = tentative - cible
	var dist: float = ecart.length()
	if dist > distance_max_px and dist > 0.0:
		var ratio := distance_max_px / dist
		ecart *= ratio
		tentative = cible + ecart

	_bar.global_position = tentative
	if _bar_overheal:
		_bar_overheal.global_position = tentative + Vector2(_bar.size.x, 0.0)

	var a: float = 1.0 - pow(1.0 - valeur_smooth, 60.0 * delta)
	_pv_affiche = lerp(_pv_affiche, pv_reel, a)

	_bar.max_value = max(1.0, max_pv)
	_bar.page = clampf(_pv_affiche, 0.0, _bar.max_value)
	_bar.value = 0.0

	if _bar_overheal:
		if overheal > 0.0 and max_pv > 0.0:
			var base_width: float = _bar.size.x
			var ratio_over: float = overheal / max_pv
			var width_ext: float = max(base_width * ratio_over, 0.0)

			_bar_overheal.size = Vector2(width_ext, _bar.size.y)
			_bar_overheal.show()

			var vis := _bar_overheal.visible
			if _dbg_prev_over_visible != vis:
				_dbg_prev_over_visible = vis
				_log(DebugLevel.ETATS, "Overheal bar visible=%s" % str(vis), "over_vis")

			if _diff(width_ext, _dbg_prev_over_width, 0.5):
				_dbg_prev_over_width = width_ext
				_log(DebugLevel.VERBEUX, "Overheal width=%.1f (ratio=%.3f)" % [width_ext, ratio_over], "over_w")
		else:
			_bar_overheal.size.x = 0.0
			_bar_overheal.hide()

			if _dbg_prev_over_visible != false:
				_dbg_prev_over_visible = false
				_log(DebugLevel.ETATS, "Overheal bar visible=false", "over_vis")

func _refresh_activation(force_show: bool) -> void:
	if _bar == null or _hote == null or _sante == null:
		_actif_ui = false
		return

	if _mort:
		if _actif_ui:
			_log(DebugLevel.ETATS, "Hide UI (mort)", "hide_mort")
		_actif_ui = false
		_bar.hide()
		if _bar_overheal:
			_bar_overheal.hide()
		return

	var ennemi_actif: bool = _hote.is_physics_processing()
	var overheal_now: float = _sante.get_overheal()
	var pv_reel: float = _sante.pv

	var doit_montrer: bool
	if toujours_visible:
		doit_montrer = true
	else:
		doit_montrer = force_show or (((pv_reel < _sante.max_pv) or (overheal_now > 0.0)) and ennemi_actif)

	if doit_montrer:
		if not _actif_ui:
			_pv_affiche = pv_reel
			_bar.max_value = max(1.0, float(_sante.max_pv))
			_bar.page = clampf(_pv_affiche, 0.0, _bar.max_value)
			_bar.value = 0.0

			var pos := _hote.global_position + offset
			_bar.global_position = pos
			if _bar_overheal:
				_bar_overheal.global_position = pos + Vector2(_bar.size.x, 0.0)

			_log(DebugLevel.ETATS, "Show UI (pv=%.1f max=%d over=%.1f active=%s)" % [pv_reel, _sante.max_pv, overheal_now, str(ennemi_actif)], "show")

		_bar.show()
		if _bar_overheal:
			_bar_overheal.show()
		_actif_ui = true
	else:
		if _actif_ui:
			_log(DebugLevel.ETATS, "Hide UI (pv=%.1f max=%d over=%.1f active=%s)" % [pv_reel, _sante.max_pv, overheal_now, str(ennemi_actif)], "hide")
			_bar.hide()
			if _bar_overheal:
				_bar_overheal.hide()
		_actif_ui = false

func _on_hote_mort() -> void:
	_mort = true
	_dead_lock = true
	_actif_ui = false
	if _bar:
		_bar.hide()
	if _bar_overheal:
		_bar_overheal.hide()
	_log(DebugLevel.ETATS, "Signal mort -> lock UI", "sig_mort")

func _on_hote_reapparu() -> void:
	if not _dead_lock:
		_log(DebugLevel.VERBEUX, "Signal reapparu ignoré (dead_lock=false)", "sig_reap")
		return

	_dead_lock = false
	_mort = false

	if _sante and _bar:
		var pv_reel: float = _sante.pv
		var max_pv_now: float = _sante.max_pv
		_pv_affiche = pv_reel
		_bar.max_value = max(1.0, max_pv_now)
		_bar.page = clampf(_pv_affiche, 0.0, _bar.max_value)
		_bar.value = 0.0

	if _bar and _hote:
		var pos := _hote.global_position + offset
		_bar.global_position = pos
		if _bar_overheal:
			_bar_overheal.global_position = pos + Vector2(_bar.size.x, 0.0)

	_actif_ui = false
	_refresh_activation(toujours_visible)
	_log(DebugLevel.ETATS, "Signal reapparu -> unlock UI", "sig_reap")
