extends Node
class_name BarPV

@export_node_path("Node2D") var chemin_hote: NodePath
@export_node_path("HScrollBar") var chemin_bar: NodePath
@export_node_path("Node") var chemin_sante: NodePath

@export var offset: Vector2 = Vector2(0, 0)
@export_range(10.0, 1000.0, 1.0) var vitesse_px_s: float = 450.0
@export_range(0.0, 1.0, 0.01) var valeur_smooth: float = 0.08
@export var toujours_visible: bool = false
@export_range(0.0, 500.0, 1.0) var distance_max_px: float = 60.0
@export var frames_activation: int = 3

var _hote: Node2D
var _bar: HScrollBar
var _sante: Sante
var _pv_affiche: float = 0.0

var _mort: bool = false
var _actif_ui: bool = false
var _dead_lock: bool = false
var _frame_activation: int = 0

func _ready() -> void:
	_hote = get_node_or_null(chemin_hote) as Node2D
	_sante = get_node_or_null(chemin_sante) as Sante

	var bar_node := get_node_or_null(chemin_bar)
	if bar_node is HScrollBar:
		_bar = bar_node as HScrollBar
	else:
		var bar_desc := "null" if bar_node == null else bar_node.get_class()
		push_warning("chemin_bar invalide ou type ≠ HScrollBar: %s" % bar_desc)

	if _bar:
		_bar.top_level = true
		_bar.focus_mode = Control.FOCUS_NONE
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.step = 0.0

	if _sante and _bar:
		var max_pv_init: float = _sante.max_pv
		var pv_init: float = _sante.pv
		_pv_affiche = pv_init
		_bar.min_value = 0.0
		_bar.max_value = max(1.0, max_pv_init)
		_bar.value = 0.0
		_bar.page = clampf(_pv_affiche, 0.0, _bar.max_value)

	if _hote and _bar:
		_bar.global_position = _hote.global_position + offset

	if _hote:
		if _hote.has_signal("mort"):
			_hote.connect("mort", Callable(self, "_on_hote_mort"))
		if _hote.has_signal("reapparu"):
			_hote.connect("reapparu", Callable(self, "_on_hote_reapparu"))

	if _sante and _bar and _hote:
		_refresh_activation(true, _sante.pv, _sante.max_pv)
	else:
		_actif_ui = false

func _process(delta: float) -> void:
	if _hote == null or _bar == null or _sante == null:
		return

	var pv_reel: float = _sante.pv
	var max_pv: float = _sante.max_pv

	if _frame_activation == 0:
		_refresh_activation(false, pv_reel, max_pv)
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

	var a: float = 1.0 - pow(1.0 - valeur_smooth, 60.0 * delta)
	_pv_affiche = lerp(_pv_affiche, pv_reel, a)
	_bar.max_value = max(1.0, max_pv)
	_bar.page = clampf(_pv_affiche, 0.0, _bar.max_value)
	_bar.value = 0.0

func _refresh_activation(force_show: bool, pv_reel: float, max_pv: float) -> void:
	if _bar == null or _hote == null or _sante == null:
		_actif_ui = false
		return

	if _mort:
		_actif_ui = false
		_bar.hide()
		return

	var ennemi_actif: bool = _hote.is_physics_processing()

	var doit_montrer: bool
	if toujours_visible:
		doit_montrer = true
	else:
		doit_montrer = force_show or (pv_reel < max_pv and ennemi_actif)

	if doit_montrer:
		if not _actif_ui:
			_pv_affiche = pv_reel
			_bar.max_value = max(1.0, max_pv)
			_bar.page = clampf(_pv_affiche, 0.0, _bar.max_value)
			_bar.value = 0.0
			_bar.global_position = _hote.global_position + offset
			_bar.show()
		_actif_ui = true
	else:
		if _actif_ui:
			_bar.hide()
		_actif_ui = false

func _on_hote_mort() -> void:
	_mort = true
	_dead_lock = true
	_actif_ui = false
	if _bar:
		_bar.hide()

func _on_hote_reapparu() -> void:
	if not _dead_lock:
		return

	_dead_lock = false
	_mort = false

	if _sante:
		var pv_reel: float = _sante.pv
		var max_pv_now: float = _sante.max_pv
		_pv_affiche = pv_reel

		if _bar:
			_bar.max_value = max(1.0, max_pv_now)
			_bar.page = clampf(_pv_affiche, 0.0, _bar.max_value)
			_bar.value = 0.0

	_actif_ui = false

	if _bar and _hote:
		_bar.global_position = _hote.global_position + offset

	if _sante and _bar and _hote:
		_refresh_activation(toujours_visible, _sante.pv, _sante.max_pv)
