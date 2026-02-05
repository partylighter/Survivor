extends Label
class_name AnimLettresLabel

@export_group("Debug")
@export var debug_actif: bool = true
@export_range(0.0, 5.0, 0.1) var debug_interval_s: float = 0.6
@export var debug_max_logs: int = 16

@export_group("Texte")
@export var utiliser_texte_actuel: bool = true
@export_multiline var texte_source: String = ""
@export var attendre_texte_si_vide: bool = true
@export_range(0.0, 3.0, 0.1) var attente_max_texte_s: float = 1.0

@export_group("Intro")
@export var intro_actif: bool = true
@export_range(0.005, 0.2, 0.005) var intervalle_lettre_s: float = 0.03
@export var delai_depart_s: float = 0.0

@export_group("Idle")
@export var idle_actif: bool = true
@export_range(0.0, 0.6, 0.01) var amplitude_rotation_rad: float = 0.08
@export_range(0.0, 12.0, 0.1) var vitesse_rotation: float = 4.0
@export_range(0.0, 0.10, 0.001) var amplitude_scale: float = 0.02
@export_range(0.0, 12.0, 0.1) var vitesse_scale: float = 3.2

@export_group("Jitter (scale)")
@export var jitter_actif: bool = false
@export_range(0.0, 0.12, 0.001) var jitter_scale: float = 0.01
@export_range(0.0, 30.0, 0.1) var jitter_vitesse: float = 14.0

@export_group("Général")
@export var relancer_si_visible_change: bool = true
@export var pause_si_cache: bool = true
@export var forcer_layout_ready: bool = true

var _t: float = 0.0
var _intro_terminee: bool = false
var _src: String = ""
var _rot_base: float = 0.0
var _scale_base: Vector2 = Vector2.ONE
var _dbg_t: float = 0.0
var _dbg_left: int = 0
var _intro_running: bool = false

func _ready() -> void:
	_dbg_left = debug_max_logs
	_rot_base = rotation
	_scale_base = scale

	if forcer_layout_ready:
		update_minimum_size()
		var p := get_parent()
		if p and p is Container:
			(p as Container).queue_sort()

	await get_tree().process_frame
	await _capturer_texte_initial()

	_dbg_log_ready()

	_demarrer_sequence()

func relancer_depuis_texte_actuel() -> void:
	if _intro_running:
		_dbg("Relance demandée mais intro déjà en cours -> ignorée")
		return

	_src = text
	_dbg("Relance depuis texte actuel -> len=%d | '%s'" % [_src.length(), _src])
	_demarrer_sequence()

func set_texte_et_relancer(nouveau_texte: String) -> void:
	text = nouveau_texte
	_src = nouveau_texte
	_dbg("set_texte_et_relancer -> len=%d | '%s'" % [_src.length(), _src])
	_demarrer_sequence()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and relancer_si_visible_change:
		_dbg("Visibility changed -> vis_in_tree=%s visible=%s" % [is_visible_in_tree(), visible])
		if is_visible_in_tree():
			_demarrer_sequence()
		elif pause_si_cache:
			_t = 0.0

func _capturer_texte_initial() -> void:
	var t_inspector := text
	var t_source := texte_source

	if utiliser_texte_actuel:
		_src = t_inspector
	else:
		_src = t_source

	if _src.strip_edges() == "" and t_source.strip_edges() != "":
		_src = t_source
		text = _src
		_dbg("Texte actuel vide -> utilisation texte_source len=%d" % _src.length())

	if _src.strip_edges() == "" and attendre_texte_si_vide:
		var waited := 0.0
		_dbg("Texte toujours vide -> attente jusqu'à %.2fs" % attente_max_texte_s)
		while waited < attente_max_texte_s and is_instance_valid(self):
			await get_tree().process_frame
			waited += get_process_delta_time()
			if text.strip_edges() != "":
				_src = text
				_dbg("Texte reçu après attente -> len=%d | '%s'" % [_src.length(), _src])
				return
		_dbg("Fin attente -> texte toujours vide")

func _demarrer_sequence() -> void:
	_t = 0.0
	_rot_base = rotation
	_scale_base = scale

	if _src.strip_edges() == "":
		visible_characters = -1
		_intro_terminee = true
		_intro_running = false
		_dbg("Aucun texte -> stop (rien à afficher)")
		return

	text = _src

	if not intro_actif:
		visible_characters = -1
		_intro_terminee = true
		_intro_running = false
		_dbg("Intro OFF -> visible_characters=-1 len=%d" % _src.length())
		return

	_intro_terminee = false
	visible_characters = 0
	_intro_running = true

	if delai_depart_s > 0.0:
		_dbg("Délai départ: %.2fs" % delai_depart_s)
		call_deferred("_start_intro_apres_delai")
	else:
		call_deferred("_lancer_intro")

func _start_intro_apres_delai() -> void:
	await get_tree().create_timer(delai_depart_s).timeout
	_lancer_intro()

func _lancer_intro() -> void:
	var total: int = _src.length()
	_dbg("Intro start -> total chars=%d | interval=%.3fs" % [total, intervalle_lettre_s])

	while visible_characters < total and is_instance_valid(self):
		if pause_si_cache and not is_visible_in_tree():
			await get_tree().process_frame
			continue
		visible_characters += 1
		await get_tree().create_timer(intervalle_lettre_s).timeout

	_intro_terminee = true
	_intro_running = false
	visible_characters = -1
	_dbg("Intro end -> visible_characters=-1")

func _process(dt: float) -> void:
	if pause_si_cache and not is_visible_in_tree():
		return

	_t += dt

	if idle_actif and (_intro_terminee or not intro_actif):
		rotation = _rot_base + sin(_t * vitesse_rotation) * amplitude_rotation_rad

		var s := 1.0 + sin(_t * vitesse_scale) * amplitude_scale
		if jitter_actif and jitter_scale > 0.0:
			s += sin((_t * jitter_vitesse) + 12.3) * jitter_scale
		scale = _scale_base * Vector2(s, s)
	else:
		rotation = _rot_base
		scale = _scale_base

	_dbg_tick(dt)

func _dbg_log_ready() -> void:
	if not debug_actif:
		return
	var p := get_parent()
	var pname := ""
	var ptype := ""
	var is_container := false
	if p:
		pname = p.name
		ptype = p.get_class()
		is_container = (p is Container)

	_dbg("READY name=%s parent=%s(%s) container=%s vis_in_tree=%s visible=%s size=%s flagsH=%s flagsV=%s text_len=%d src_len=%d"
		% [
			name, pname, ptype, is_container,
			is_visible_in_tree(), visible, size,
			size_flags_horizontal, size_flags_vertical,
			text.length(), _src.length()
		]
	)

func _dbg_tick(dt: float) -> void:
	if not debug_actif:
		return
	_dbg_t += dt
	if _dbg_t < debug_interval_s:
		return
	_dbg_t = 0.0
	_dbg("TICK vis_in_tree=%s visible=%s size=%s pos=%s vis_chars=%d intro_done=%s text_len=%d"
		% [
			is_visible_in_tree(), visible, size, global_position,
			visible_characters, _intro_terminee, text.length()
		]
	)

func _dbg(msg: String) -> void:
	if not debug_actif:
		return
	if _dbg_left <= 0:
		return
	_dbg_left -= 1
	print("[AnimLettresLabel:%s] %s" % [name, msg])
