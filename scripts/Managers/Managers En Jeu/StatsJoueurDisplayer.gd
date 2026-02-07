extends CanvasLayer
class_name PlayerStatsDisplayer

@export var actif: bool = true
@export var debug_enabled: bool = false

var _ui_visible: bool = true
@export var ui_visible: bool = true:
	set(v):
		_ui_visible = v
		_apply_ui_visible()
	get:
		return _ui_visible

@export_node_path("StatsJoueur") var chemin_stats: NodePath
@export_node_path("Sante") var chemin_sante: NodePath
@export_node_path("Player") var chemin_player: NodePath

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(16, 16)
@export var ui_largeur_min_px: float = 520.0
@export_range(8, 64, 1) var ui_taille_police: int = 14
@export var ui_couleur_fond: Color = Color(0, 0, 0, 0.55)
@export var ui_couleur_texte: Color = Color(1, 1, 1, 0.92)
@export_range(0, 64, 1) var ui_espace_px: int = 16

@export_group("Raccourci")
@export var toggle_key: Key = KEY_F2

var stats: StatsJoueur
var sante: Sante
var joueur: Player

var _panel: Panel
var _margin: MarginContainer
var _root: VBoxContainer
var _stylebox: StyleBoxFlat
var _title: Label
var _sub: Label
var _row: HBoxContainer

var _pairs: Dictionary = {}
var _cache: Dictionary = {}

func _ready() -> void:
	_ui_visible = ui_visible
	stats = get_node_or_null(chemin_stats) as StatsJoueur
	sante = get_node_or_null(chemin_sante) as Sante
	joueur = get_node_or_null(chemin_player) as Player
	_creer_ui()
	_appliquer_style()
	_apply_ui_visible()
	_refresh()

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[PlayerStatsDisplayer] ", msg)

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
	_root.add_theme_constant_override("separation", 6)

	var header := VBoxContainer.new()
	_root.add_child(header)
	header.add_theme_constant_override("separation", 2)

	_title = Label.new()
	_sub = Label.new()
	header.add_child(_title)
	header.add_child(_sub)

	_root.add_child(HSeparator.new())

	_row = HBoxContainer.new()
	_root.add_child(_row)
	_row.add_theme_constant_override("separation", ui_espace_px)

	_add_pair("PV", "—")
	_add_pair("Vitesse", "—")
	_add_pair("Chance", "—")
	_add_pair("Dash", "—")

func _add_pair(k: String, v: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)

	var lk := Label.new()
	lk.text = k
	lk.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))

	var lv := Label.new()
	lv.text = v
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	box.add_child(lk)
	box.add_child(lv)

	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_row.add_child(box)

	_pairs[k] = lv

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

	_title.text = "JOUEUR"
	_title.add_theme_font_size_override("font_size", ui_taille_police + 3)
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))

	_sub.text = "F2 pour afficher/masquer"
	_sub.add_theme_font_size_override("font_size", max(8, ui_taille_police - 2))
	_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))

	for c in _panel.get_children():
		_apply_font_recursive(c)

func _apply_font_recursive(n: Node) -> void:
	if n is Label:
		var l := n as Label
		if l != _title:
			l.add_theme_font_size_override("font_size", ui_taille_police)
			if not l.has_theme_color_override("font_color"):
				l.add_theme_color_override("font_color", ui_couleur_texte)
	for ch in n.get_children():
		_apply_font_recursive(ch)

func _set_val(k: String, v: String) -> void:
	if _cache.get(k, "") == v:
		return
	_cache[k] = v
	var lab := _pairs.get(k, null) as Label
	if lab != null:
		lab.text = v

func _process(_dt: float) -> void:
	if not actif or _panel == null or not _panel.visible:
		return

	_panel.position = ui_position

	if stats == null or not is_instance_valid(stats):
		stats = get_node_or_null(chemin_stats) as StatsJoueur
	if sante == null or not is_instance_valid(sante):
		sante = get_node_or_null(chemin_sante) as Sante
	if joueur == null or not is_instance_valid(joueur):
		joueur = get_node_or_null(chemin_player) as Player

	_refresh()

func _refresh() -> void:
	var pv_now: int = 0
	var pv_max: int = 0
	var overheal_now: float = 0.0

	if sante != null and is_instance_valid(sante):
		pv_now = int(sante.pv)
		pv_max = int(sante.max_pv)
		if sante.has_method("get_overheal"):
			overheal_now = float(sante.get_overheal())

	var vitesse_now: float = 0.0
	var chance_now: float = 0.0
	var dash_actuel: int = 0
	var dash_max: int = 0

	if stats != null and is_instance_valid(stats):
		if stats.has_method("get_vitesse_effective"):
			vitesse_now = float(stats.get_vitesse_effective())
		if stats.has_method("get_chance"):
			chance_now = float(stats.get_chance())
		if stats.has_method("get_dash_max_effectif"):
			dash_max = int(stats.get_dash_max_effectif())

	if joueur != null and is_instance_valid(joueur):
		dash_actuel = int(joueur.dash_charges_actuelles)

	var txt_pv := "%d / %d" % [pv_now, pv_max]
	if overheal_now > 0.0:
		txt_pv += "  (+%.0f)" % overheal_now

	_set_val("PV", txt_pv)
	_set_val("Vitesse", "%.0f" % vitesse_now)
	_set_val("Chance", "%.1f%%" % chance_now)
	_set_val("Dash", "%d / %d" % [dash_actuel, dash_max])

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			ui_visible = not ui_visible
			_dbg("toggle key=%s -> ui=%s" % [str(toggle_key), str(_ui_visible)])
