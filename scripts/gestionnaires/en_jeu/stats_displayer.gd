extends CanvasLayer
class_name StatsDisplayer

@export var actif: bool = true
@export var debug_enabled: bool = false

var _ui_visible: bool = true
@export var ui_visible: bool = true:
	set(v):
		_ui_visible = v
		_apply_ui_visible()
	get:
		return _ui_visible

@export_node_path("Node") var chemin_stats: NodePath
@export_node_path("GestionnaireEnnemis") var chemin_ennemis: NodePath

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(16, 16)
@export var ui_largeur_min_px: float = 900.0
@export_range(8, 64, 1) var ui_taille_police: int = 14
@export var ui_couleur_fond: Color = Color(0, 0, 0, 0.55)
@export var ui_couleur_texte: Color = Color(1, 1, 1, 0.92)
@export_range(0, 64, 1) var ui_espace_px: int = 14

@export_group("Raccourci")
@export var toggle_key: Key = KEY_F1

var stats_ref: StatsVagues
var ennemis_ref: GestionnaireEnnemis

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
	stats_ref = get_node_or_null(chemin_stats) as StatsVagues
	ennemis_ref = get_node_or_null(chemin_ennemis) as GestionnaireEnnemis
	_creer_ui()
	_appliquer_style()
	_apply_ui_visible()
	_dbg("ready ui=%s actif=%s" % [str(_ui_visible), str(actif)])

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[StatsDisplayer] ", msg)

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
	_margin.anchor_left = 0.0
	_margin.anchor_top = 0.0
	_margin.anchor_right = 0.0
	_margin.anchor_bottom = 0.0
	_margin.offset_left = 0
	_margin.offset_top = 0
	_margin.offset_right = ui_largeur_min_px
	_margin.offset_bottom = 0
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

	_add_pair("Vague", "—")
	_add_pair("Temps", "—")
	_add_pair("Vivants", "—")
	_add_pair("Kills", "—")
	_add_pair("Score", "—")
	_add_pair("Kills vague", "—")
	_add_pair("Score vague", "—")

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

	_title.text = "STATS VAGUES"
	_title.add_theme_font_size_override("font_size", ui_taille_police + 3)
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))

	_sub.text = "F1 pour afficher/masquer"
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

func _set_val(key: String, value: String) -> void:
	if _cache.get(key, "") == value:
		return
	_cache[key] = value
	var lab := _pairs.get(key, null) as Label
	if lab != null:
		lab.text = value

func _process(_dt: float) -> void:
	if not actif or _panel == null or not _panel.visible:
		return

	_panel.position = ui_position

	if stats_ref == null or not is_instance_valid(stats_ref):
		stats_ref = get_node_or_null(chemin_stats) as StatsVagues
	if ennemis_ref == null or not is_instance_valid(ennemis_ref):
		ennemis_ref = get_node_or_null(chemin_ennemis) as GestionnaireEnnemis

	var vivants_now: int = 0
	var kills_tot_now: int = 0
	var score_tot_now: int = 0
	var vague_id: int = -1
	var cycle: int = 0
	var kills_vague_now: int = 0
	var score_vague_now: int = 0
	var temps_total_s: float = 0.0
	var temps_vague_s: float = 0.0

	if ennemis_ref != null and is_instance_valid(ennemis_ref):
		vivants_now = ennemis_ref.ennemis.size()
		kills_tot_now = ennemis_ref.ennemis_tues_total
		vague_id = ennemis_ref.i_vague
		cycle = ennemis_ref.cycle_vagues
		kills_vague_now = ennemis_ref.tues_vague
		temps_total_s = ennemis_ref.temps_total_s
		temps_vague_s = ennemis_ref.t_vague

	if stats_ref != null and is_instance_valid(stats_ref):
		var sv: Dictionary = stats_ref.get_stats_vague()
		score_tot_now = stats_ref.get_score_total()
		score_vague_now = int(sv.get("score", score_vague_now))

	_set_val("Vague", "V%d | C%d" % [vague_id, cycle])
	_set_val("Temps", "%s | %s" % [_format_secs(temps_total_s), _format_secs(temps_vague_s)])
	_set_val("Vivants", str(vivants_now))
	_set_val("Kills", str(kills_tot_now))
	_set_val("Score", str(score_tot_now))
	_set_val("Kills vague", str(kills_vague_now))
	_set_val("Score vague", str(score_vague_now))

func _format_secs(t: float) -> String:
	var total_sec: int = int(max(t, 0.0))
	var minutes: int = int(total_sec / 60.0)
	var secondes: int = total_sec % 60
	return str(minutes) + "m " + str(secondes) + "s"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			ui_visible = not ui_visible
			_dbg("toggle key=%s -> ui=%s" % [str(toggle_key), str(_ui_visible)])
