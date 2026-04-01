extends CanvasLayer
class_name ZoneDisplayer

@export var actif: bool = true
@export var debug_enabled: bool = false

var _ui_visible: bool = true
@export var ui_visible: bool = true:
	set(v):
		_ui_visible = v
		_apply_ui_visible()
	get:
		return _ui_visible

@export_node_path("GestionnaireZones") var chemin_zones: NodePath

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(16, 260)
@export var ui_largeur_min_px: float = 360.0
@export_range(8, 64, 1) var ui_taille_police: int = 14
@export var ui_couleur_fond: Color = Color(0, 0, 0, 0.55)
@export var ui_couleur_texte: Color = Color(1, 1, 1, 0.92)
@export_range(0, 64, 1) var ui_espace_lignes: int = 6

@export_group("Raccourci")
@export var toggle_key: Key = KEY_F8

var zones_ref: GestionnaireZones
var _joueur: Node2D = null

var _panel: Panel
var _margin: MarginContainer
var _root: VBoxContainer
var _stylebox: StyleBoxFlat
var _title: Label
var _sub: Label
var _grid: GridContainer
var _rows: Dictionary = {}
var _cache: Dictionary = {}

func _ready() -> void:
	_ui_visible = ui_visible
	zones_ref = _resoudre_gestionnaire_zones()
	_joueur = get_tree().get_first_node_in_group("joueur_principal") as Node2D
	_creer_ui()
	_appliquer_style()
	_apply_ui_visible()
	_refresh()

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[ZoneDisplayer] ", msg)

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

	_add_row("Zone", "\u2014")
	_add_row("Index", "\u2014")
	_add_row("Bornes X", "\u2014")
	_add_row("Progression", "\u2014")
	_add_row("Reste", "\u2014")
	_add_row("Spawn/s", "\u2014")
	_add_row("Cap zone", "\u2014")
	_add_row("Boss", "\u2014")
	_add_row("Avance", "\u2014")

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

	_title.text = "ZONE ACTIVE"
	_title.add_theme_font_size_override("font_size", ui_taille_police + 3)
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))

	_sub.text = "F8 pour afficher/masquer"
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

	if zones_ref == null or not is_instance_valid(zones_ref):
		zones_ref = _resoudre_gestionnaire_zones()

	if not is_instance_valid(_joueur):
		_joueur = get_tree().get_first_node_in_group("joueur_principal") as Node2D

	_refresh()

func _refresh() -> void:
	if zones_ref == null or not is_instance_valid(zones_ref):
		_set_val("Zone", "(GestionnaireZones introuvable)")
		_set_val("Index", "\u2014")
		_set_val("Bornes X", "\u2014")
		_set_val("Progression", "\u2014")
		_set_val("Reste", "\u2014")
		_set_val("Spawn/s", "\u2014")
		_set_val("Cap zone", "\u2014")
		_set_val("Boss", "\u2014")
		_set_val("Avance", "\u2014")
		return

	var zone: ZoneDefinition = zones_ref.zone_active
	if zone == null:
		_set_val("Zone", "(hors zone)")
		_set_val("Index", str(zones_ref._zone_idx_active))
		_set_val("Bornes X", "\u2014")
		_set_val("Progression", "\u2014")
		_set_val("Reste", "\u2014")
		_set_val("Spawn/s", "\u2014")
		_set_val("Cap zone", "\u2014")
		_set_val("Boss", "Non")
		_set_val("Avance", "Libre")
		return

	_set_val("Zone", String(zone.nom))
	_set_val("Index", str(zones_ref._zone_idx_active))
	_set_val("Bornes X", "%.0f -> %.0f" % [zone.x_debut_px, zone.x_fin_px])

	if is_instance_valid(_joueur):
		var longueur: float = zone.x_fin_px - zone.x_debut_px
		var parcouru: float = clampf(_joueur.global_position.x - zone.x_debut_px, 0.0, longueur)
		var reste: float    = maxf(zone.x_fin_px - _joueur.global_position.x, 0.0)
		var pct: float      = (parcouru / longueur * 100.0) if longueur > 0.0 else 0.0
		_set_val("Progression", "%.0f%% (%.0f / %.0f px)" % [pct, parcouru, longueur])
		_set_val("Reste", "%.0f px" % reste)
	else:
		_set_val("Progression", "(joueur introuvable)")
		_set_val("Reste", "\u2014")

	_set_val("Spawn/s", "%.2f" % zone.apparitions_par_sec)
	_set_val("Cap zone", str(zone.max_ennemis_zone))
	_set_val("Boss", "Oui" if zone.est_zone_boss else "Non")
	_set_val("Avance", "Bloquee" if zones_ref.avance_bloquee else "Libre")

func _resoudre_gestionnaire_zones() -> GestionnaireZones:
	var ref := get_node_or_null(chemin_zones) as GestionnaireZones
	if ref != null:
		return ref

	return _trouver_gestionnaire_zones(get_tree().current_scene)

func _trouver_gestionnaire_zones(racine: Node) -> GestionnaireZones:
	if racine == null:
		return null
	if racine is GestionnaireZones:
		return racine as GestionnaireZones
	for enfant in racine.get_children():
		var trouve := _trouver_gestionnaire_zones(enfant)
		if trouve != null:
			return trouve
	return null

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			ui_visible = not ui_visible
			_dbg("toggle key=%s -> ui=%s" % [str(toggle_key), str(_ui_visible)])
