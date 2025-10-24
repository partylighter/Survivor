extends Node
class_name BarPV

@export_node_path("Node2D") var chemin_hote: NodePath
@export_node_path("HScrollBar") var chemin_bar: NodePath
@export_node_path("Node") var chemin_sante: NodePath

@export var offset: Vector2 = Vector2(0, 0)
@export_range(10.0, 1000.0, 1.0) var vitesse_px_s: float = 450.0
@export_range(0.0, 1.0, 0.01) var valeur_smooth: float = 0.08

@export var debug_enabled: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_every_s: float = 0.5
@export var forcer_theme_simple: bool = false

var _hote: Node2D
var _bar: HScrollBar
var _sante: Node
var _pv_affiche: float = 0.0
var _t_debug: float = 0.0

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[BarPV] ", msg)

func _ready() -> void:
	_hote = get_node_or_null(chemin_hote) as Node2D
	_sante = get_node_or_null(chemin_sante)

	var bar_node := get_node_or_null(chemin_bar)
	if bar_node is HScrollBar:
		_bar = bar_node as HScrollBar
	else:
		var bar_desc := "null" if bar_node == null else bar_node.get_class()
		push_warning("chemin_bar invalide ou type ≠ HScrollBar: %s" % bar_desc)

	_dbg("READY hote=%s bar=%s sante=%s" % [str(_hote), str(_bar), str(_sante)])
	if _hote == null: push_warning("chemin_hote invalide")
	if _sante == null: push_warning("chemin_sante invalide")

	if _bar:
		_bar.top_level = true
		_bar.focus_mode = Control.FOCUS_NONE
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.step = 0.0
		if _bar.size == Vector2.ZERO:
			_bar.custom_minimum_size = Vector2(80, 8)
		if _hote:
			_bar.global_position = _hote.global_position + offset

		if forcer_theme_simple:
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color(0,0,0,0.5)
			bg.content_margin_left = 0; bg.content_margin_right = 0
			bg.content_margin_top = 0; bg.content_margin_bottom = 0
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color(1,0,0,0.9)
			_bar.add_theme_stylebox_override("scroll", bg)
			_bar.add_theme_stylebox_override("grabber", fill)
			_bar.add_theme_stylebox_override("grabber_highlight", fill)
			_bar.add_theme_stylebox_override("grabber_pressed", fill)

	if _sante and _bar:
		var max_pv: float = float(_sante.get("max_pv"))
		var pv: float = float(_sante.get("pv"))
		_pv_affiche = pv
		# Utiliser 'page' comme remplissage, 'value' ancré à 0 pour coller à gauche
		_bar.min_value = 0.0
		_bar.max_value = max(1.0, max_pv)
		_bar.value = 0.0
		_bar.page = clampf(_pv_affiche, 0.0, _bar.max_value)
		_dbg("Init PV: pv=%s / max=%s -> page=%s value=%s" % [str(pv), str(_bar.max_value), str(_bar.page), str(_bar.value)])

func _process(delta: float) -> void:
	if _hote and _bar:
		var cible: Vector2 = _hote.global_position + offset
		_bar.global_position = _bar.global_position.move_toward(cible, vitesse_px_s * delta)

	if _sante and _bar:
		var pv_reel: float = float(_sante.get("pv"))
		var max_pv: float = float(_sante.get("max_pv"))
		var a: float = 1.0 - pow(1.0 - valeur_smooth, 60.0 * delta)
		_pv_affiche = lerp(_pv_affiche, pv_reel, a)

		_bar.max_value = max(1.0, max_pv)
		_bar.page = clampf(_pv_affiche, 0.0, _bar.max_value) # largeur du “remplissage”
		_bar.value = 0.0 # collé à gauche

		_t_debug += delta
		if debug_enabled and _t_debug >= debug_log_every_s:
			_t_debug = 0.0
			_dbg("PV tick: reel=%s affiche=%s max=%s a=%s page=%s value=%s"
				% [str(pv_reel), str(_pv_affiche), str(_bar.max_value), str(a), str(_bar.page), str(_bar.value)])

		if debug_enabled and (_bar.page <= 0.0 and pv_reel > 0.0):
			_dbg("Alerte: page=0 mais pv_reel>0 -> overrides de thème 'grabber' probablement transparents.")
