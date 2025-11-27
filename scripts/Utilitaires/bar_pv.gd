extends Node
class_name BarPV

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

var _overheal_prev: float = -1.0


func _d(msg: String) -> void:
	if debug_bar_pv:
		print("[BarPV] ", msg)


func _ready() -> void:
	_hote = get_node_or_null(chemin_hote) as Node2D
	_sante = get_node_or_null(chemin_sante) as Sante
	_loot = get_node_or_null(chemin_loot) as GestionnaireLoot

	var bar_node := get_node_or_null(chemin_bar)
	if bar_node is HScrollBar:
		_bar = bar_node as HScrollBar
	else:
		var bar_desc := "null" if bar_node == null else bar_node.get_class()
		push_warning("chemin_bar invalide ou type ≠ HScrollBar: %s" % bar_desc)

	var bar_over_node := get_node_or_null(chemin_bar_overheal)
	if bar_over_node is HScrollBar:
		_bar_overheal = bar_over_node as HScrollBar
	else:
		var bar_desc2 := "null" if bar_over_node == null else bar_over_node.get_class()
		push_warning("chemin_bar_overheal invalide ou type ≠ HScrollBar: %s" % bar_desc2)

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
		_bar_overheal.top_level = true
		_bar_overheal.focus_mode = Control.FOCUS_NONE
		_bar_overheal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar_overheal.step = 0.0
		_bar_overheal.z_index = 0

		_bar_overheal.size.x = 0.0
		_bar_overheal.size.y = _bar.size.y if _bar else _bar_overheal.size.y

		_bar_overheal.min_value = 0.0
		_bar_overheal.max_value = 1.0
		_bar_overheal.value = 0.0
		_bar_overheal.page = 1.0

		_bar_overheal.hide()
		_d("Init overheal bar: size=%s (hidden)" % str(_bar_overheal.size))

	if _hote and _bar:
		var pos := _hote.global_position + offset
		_bar.global_position = pos
		if _bar_overheal:
			_bar_overheal.global_position = pos + Vector2(_bar.size.x, 0.0)

	var init_over: float = 0.0
	var init_max: int = 0
	if _sante:
		init_over = _sante.get_overheal()
		init_max = _sante.max_pv
		_overheal_prev = init_over
	print("[BarPV] Init overheal: over=%.1f max_pv=%d" % [init_over, init_max])

	if _hote:
		if _hote.has_signal("mort"):
			_hote.connect("mort", Callable(self, "_on_hote_mort"))
		if _hote.has_signal("reapparu"):
			_hote.connect("reapparu", Callable(self, "_on_hote_reapparu"))

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

	if _overheal_prev < 0.0:
		_overheal_prev = overheal
	elif overheal != _overheal_prev:
		print("[BarPV] Overheal change: %.1f -> %.1f" % [_overheal_prev, overheal])
		_overheal_prev = overheal

	if _frame_activation == 0:
		_refresh_activation(false)
	_frame_activation = (_frame_activation + 1) % max(frames_activation, 1)

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
			var width_ext: float = base_width * ratio_over
			width_ext = max(width_ext, 0.0)

			_bar_overheal.size = Vector2(width_ext, _bar.size.y)
			_bar_overheal.show()
		else:
			_bar_overheal.size.x = 0.0
			_bar_overheal.hide()


func _refresh_activation(force_show: bool) -> void:
	if _bar == null or _hote == null or _sante == null:
		_actif_ui = false
		return

	if _mort:
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

		_bar.show()
		if _bar_overheal:
			_bar_overheal.show()
		_actif_ui = true
	else:
		if _actif_ui:
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


func _on_hote_reapparu() -> void:
	if not _dead_lock:
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
