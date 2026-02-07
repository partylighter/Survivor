extends CanvasLayer
class_name EnemyCountDisplayer

@export var actif: bool = true
@export var debug_enabled: bool = false

var _ui_visible: bool = true
@export var ui_visible: bool = true:
	set(v):
		_ui_visible = v
		_apply_ui_visible()
	get:
		return _ui_visible

@export_node_path("GestionnaireEnnemis") var chemin_ennemis: NodePath

@export_group("Perf")
@export var maj_interval_frames: int = 6:
	set(v): _maj_interval_frames = max(v, 1)
	get: return _maj_interval_frames

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(16, 16)
@export var ui_largeur_min_px: float = 360.0
@export_range(8, 64, 1) var ui_taille_police: int = 14
@export var ui_couleur_fond: Color = Color(0, 0, 0, 0.55)
@export var ui_couleur_texte: Color = Color(1, 1, 1, 0.92)
@export_range(0, 64, 1) var ui_espace_lignes: int = 6

@export_group("Raccourci")
@export var toggle_key: Key = KEY_F2

var ennemis_ref: GestionnaireEnnemis

var _panel: Panel
var _margin: MarginContainer
var _root: VBoxContainer
var _stylebox: StyleBoxFlat
var _title: Label
var _sub: Label
var _grid: GridContainer
var _rows: Dictionary = {}
var _cache: Dictionary = {}

var _maj_interval_frames: int = 6
var _frame: int = 0

func _ready() -> void:
	_ui_visible = ui_visible
	ennemis_ref = get_node_or_null(chemin_ennemis) as GestionnaireEnnemis
	_creer_ui()
	_appliquer_style()
	_apply_ui_visible()

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[EnemyCountDisplayer] ", msg)

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

	_add_row("Total", "—")
	_add_row("Invalid", "—")
	_add_row("FULL (LOD0)", "—")
	_add_row("LITE (LOD1)", "—")
	_add_row("OFF  (LOD2)", "—")
	_add_row("Full limit", "—")
	_add_row("Lite limit", "—")
	_add_row("Foule actifs", "—")
	_add_row("Foule budget/frame", "—")

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

	_title.text = "ENEMIS (LOD)"
	_title.add_theme_font_size_override("font_size", ui_taille_police + 3)
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))

	_sub.text = "F2 pour afficher/masquer"
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

func _process(_dt: float) -> void:
	if not actif or _panel == null or not _panel.visible:
		return

	_panel.position = ui_position

	_frame += 1
	if _frame < _maj_interval_frames:
		return
	_frame = 0

	if ennemis_ref == null or not is_instance_valid(ennemis_ref):
		ennemis_ref = get_node_or_null(chemin_ennemis) as GestionnaireEnnemis
		if ennemis_ref == null:
			_set_val("Total", "—")
			_set_val("Invalid", "—")
			_set_val("FULL (LOD0)", "—")
			_set_val("LITE (LOD1)", "—")
			_set_val("OFF  (LOD2)", "—")
			_set_val("Full limit", "—")
			_set_val("Lite limit", "—")
			_set_val("Foule actifs", "—")
			_set_val("Foule budget/frame", "—")
			return

	var total: int = ennemis_ref.ennemis.size()
	var full: int = 0
	var lite: int = 0
	var off: int = 0
	var invalid: int = 0

	for n: Node2D in ennemis_ref.ennemis:
		if not is_instance_valid(n):
			invalid += 1
			continue

		var mode: int = -1
		if n.has_meta("lod_mode"):
			var vv: Variant = n.get_meta("lod_mode")
			if typeof(vv) == TYPE_INT:
				mode = int(vv)

		match mode:
			0: full += 1
			1: lite += 1
			2: off += 1
			_: off += 1

	var full_limit: int = max(ennemis_ref.max_full_actifs, 0)
	var buffer_limit: int = max(ennemis_ref.max_buffer_actifs, full_limit)
	var lite_limit: int = max(0, buffer_limit - full_limit)

	var foule_actifs: int = 0
	if ennemis_ref.foule_actif:
		foule_actifs = ennemis_ref._foule_liste.size()

	_set_val("Total", str(total))
	_set_val("Invalid", str(invalid))
	_set_val("FULL (LOD0)", "%d" % full)
	_set_val("LITE (LOD1)", "%d" % lite)
	_set_val("OFF  (LOD2)", "%d" % off)
	_set_val("Full limit", str(full_limit))
	_set_val("Lite limit", str(lite_limit))
	_set_val("Foule actifs", str(foule_actifs))
	_set_val("Foule budget/frame", str(int(ennemis_ref.foule_budget_par_frame)))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			ui_visible = not ui_visible
			_dbg("toggle key=%s -> ui=%s" % [str(toggle_key), str(_ui_visible)])
