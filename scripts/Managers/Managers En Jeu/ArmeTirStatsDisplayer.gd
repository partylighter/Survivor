extends CanvasLayer
class_name ArmTirStatsDisplayer

@export var actif: bool = true
@export var debug_enabled: bool = false

var _ui_visible: bool = true
@export var ui_visible: bool = true:
	set(v):
		_ui_visible = v
		_apply_ui_visible()
	get:
		return _ui_visible

@export_node_path("GestionnaireUpgradesArmeTir") var chemin_upgrades: NodePath

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(16, 140)
@export_range(8, 64, 1) var ui_taille_police: int = 14
@export var ui_largeur_min_px: float = 360.0
@export var ui_couleur_fond: Color = Color(0, 0, 0, 0.55)
@export var ui_couleur_texte: Color = Color(1, 1, 1, 0.92)
@export_range(0, 32, 1) var ui_espace_lignes: int = 6

@export_group("Raccourci")
@export var toggle_key: Key = KEY_F3

var arme: ArmeTir
var upgrades: GestionnaireUpgradesArmeTir

var _panel: Panel
var _margin: MarginContainer
var _root: VBoxContainer
var _stylebox: StyleBoxFlat

var _title: Label
var _sub: Label

var _grid_arme: GridContainer
var _grid_proj: GridContainer

var _rows_arme: Dictionary = {}
var _rows_proj: Dictionary = {}

var _dbg_last_arme_id: int = 0
var _dbg_last_upg_id: int = 0
var _dbg_last_ui: bool = true
var _dbg_missing_armed_printed: bool = false
var _dbg_missing_upg_printed: bool = false

var _cache: Dictionary = {}

func _ready() -> void:
	_ui_visible = ui_visible
	_creer_ui()
	_appliquer_style()
	_apply_ui_visible()
	_dbg("ready ui=%s actif=%s" % [str(_ui_visible), str(actif)])

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[ArmTirStatsDisplayer] ", msg)

func _apply_ui_visible() -> void:
	if _panel != null:
		_panel.visible = _ui_visible
	set_process(_ui_visible and actif)

	if _dbg_last_ui != _ui_visible:
		_dbg_last_ui = _ui_visible
		_dbg("ui_visible=%s" % str(_ui_visible))

func _creer_ui() -> void:
	_panel = Panel.new()
	add_child(_panel)
	_panel.position = ui_position
	_panel.custom_minimum_size = Vector2(ui_largeur_min_px, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_margin = MarginContainer.new()
	_panel.add_child(_margin)
	_margin.anchor_left = 0.0
	_margin.anchor_top = 0.0
	_margin.anchor_right = 1.0
	_margin.anchor_bottom = 1.0
	_margin.offset_left = 10
	_margin.offset_top = 10
	_margin.offset_right = -10
	_margin.offset_bottom = -10

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

	var sep1 := HSeparator.new()
	_root.add_child(sep1)

	var section_arme := Label.new()
	section_arme.text = "ARME"
	_root.add_child(section_arme)

	_grid_arme = GridContainer.new()
	_grid_arme.columns = 2
	_root.add_child(_grid_arme)

	_add_row(_grid_arme, _rows_arme, "Nom", "—")
	_add_row(_grid_arme, _rows_arme, "Dégâts", "—")
	_add_row(_grid_arme, _rows_arme, "Nb balles", "—")
	_add_row(_grid_arme, _rows_arme, "Dispersion", "—")
	_add_row(_grid_arme, _rows_arme, "Cooldown", "—")
	_add_row(_grid_arme, _rows_arme, "Durée active", "—")
	_add_row(_grid_arme, _rows_arme, "Recul", "—")
	_add_row(_grid_arme, _rows_arme, "Hitscan", "—")
	_add_row(_grid_arme, _rows_arme, "Tir max/frame", "—")
	_add_row(_grid_arme, _rows_arme, "Portée hitscan", "—")
	_add_row(_grid_arme, _rows_arme, "Mask tir", "—")

	var sep2 := HSeparator.new()
	_root.add_child(sep2)

	var section_proj := Label.new()
	section_proj.text = "PROJECTILES (UPGRADES)"
	_root.add_child(section_proj)

	_grid_proj = GridContainer.new()
	_grid_proj.columns = 2
	_root.add_child(_grid_proj)

	_add_row(_grid_proj, _rows_proj, "Vitesse", "—")
	_add_row(_grid_proj, _rows_proj, "Vie", "—")
	_add_row(_grid_proj, _rows_proj, "Mask", "—")
	_add_row(_grid_proj, _rows_proj, "Marge ray", "—")
	_add_row(_grid_proj, _rows_proj, "Largeur zone scan", "—")
	_add_row(_grid_proj, _rows_proj, "Rays dans zone", "—")
	_add_row(_grid_proj, _rows_proj, "Contacts avant destroy", "—")
	_add_row(_grid_proj, _rows_proj, "Ignore même cible", "—")

func _add_row(grid: GridContainer, map: Dictionary, k: String, v: String) -> void:
	var lk := Label.new()
	var lv := Label.new()
	lk.text = k
	lv.text = v
	lk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(lk)
	grid.add_child(lv)
	map[k] = lv

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
	_stylebox.content_margin_left = 0
	_stylebox.content_margin_right = 0
	_stylebox.content_margin_top = 0
	_stylebox.content_margin_bottom = 0

	_panel.add_theme_stylebox_override("panel", _stylebox)
	_panel.custom_minimum_size = Vector2(ui_largeur_min_px, 0.0)
	_panel.position = ui_position

	_title.text = "STATS ARME (TIR)"
	_title.add_theme_font_size_override("font_size", ui_taille_police + 3)
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))

	_sub.text = "F3 pour afficher/masquer"
	_sub.add_theme_font_size_override("font_size", max(8, ui_taille_police - 2))
	_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))

	var all_labels: Array[Label] = []
	all_labels.append(_sub)

	for k in _rows_arme.keys():
		all_labels.append(_rows_arme[k] as Label)
	for k in _rows_proj.keys():
		all_labels.append(_rows_proj[k] as Label)

	for c in _grid_arme.get_children():
		if c is Label:
			all_labels.append(c as Label)
	for c in _grid_proj.get_children():
		if c is Label:
			all_labels.append(c as Label)

	for l in all_labels:
		if l == null:
			continue
		if l != _title:
			l.add_theme_font_size_override("font_size", ui_taille_police)
			l.add_theme_color_override("font_color", ui_couleur_texte)

func _set_val(section: String, key: String, value: String) -> void:
	var cache_key := section + "::" + key
	if _cache.get(cache_key, "") == value:
		return
	_cache[cache_key] = value

	var dict := _rows_arme if section == "arme" else _rows_proj
	var lab := dict.get(key, null) as Label
	if lab != null:
		lab.text = value

func _process(_dt: float) -> void:
	if not actif:
		return
	if _panel == null or not _panel.visible:
		return

	if arme == null or not is_instance_valid(arme):
		var a := get_tree().get_nodes_in_group("armes_tir")
		if not a.is_empty():
			arme = a[0] as ArmeTir
			_dbg_missing_armed_printed = false
		elif not _dbg_missing_armed_printed:
			_dbg_missing_armed_printed = true
			_dbg("aucune arme dans groupe 'armes_tir'")

	if upgrades == null or not is_instance_valid(upgrades):
		upgrades = get_node_or_null(chemin_upgrades) as GestionnaireUpgradesArmeTir
		if upgrades == null:
			var u := get_tree().get_nodes_in_group("upg_arme_tir")
			if not u.is_empty():
				upgrades = u[0] as GestionnaireUpgradesArmeTir
				_dbg_missing_upg_printed = false
			elif not _dbg_missing_upg_printed:
				_dbg_missing_upg_printed = true
				_dbg("aucun upgrades dans groupe 'upg_arme_tir'")

	var aid := arme.get_instance_id() if arme != null and is_instance_valid(arme) else 0
	if aid != _dbg_last_arme_id:
		_dbg_last_arme_id = aid
		_dbg("arme=%s" % ("null" if aid == 0 else "ok id=%d nom=%s" % [aid, String(arme.nom_arme)]))

	var uid := upgrades.get_instance_id() if upgrades != null and is_instance_valid(upgrades) else 0
	if uid != _dbg_last_upg_id:
		_dbg_last_upg_id = uid
		_dbg("upgrades=%s" % ("null" if uid == 0 else "ok id=%d" % uid))

	if arme == null:
		_set_val("arme", "Nom", "(aucune)")
		return

	_set_val("arme", "Nom", String(arme.nom_arme))
	_set_val("arme", "Dégâts", str(int(arme.degats)))
	_set_val("arme", "Nb balles", str(int(arme.nb_balles)))
	_set_val("arme", "Dispersion", "%.1f°" % float(arme.dispersion_deg))
	_set_val("arme", "Cooldown", "%.3fs" % float(arme.cooldown_s))
	_set_val("arme", "Durée active", "%.3fs" % float(arme.duree_active_s))
	_set_val("arme", "Recul", "%.1f" % float(arme.recul_force))
	_set_val("arme", "Hitscan", "Oui" if arme.hitscan else "Non")
	_set_val("arme", "Tir max/frame", str(int(arme.tir_max_par_frame)))
	_set_val("arme", "Portée hitscan", "%.0fpx" % float(arme.portee_hitscan_px))
	_set_val("arme", "Mask tir", str(int(arme.mask_tir)))

	var pv: float = 0.0
	var vie: float = 0.0
	var pmask: int = 0
	var marge: float = 0.0
	var largeur: float = 0.0
	var rays: int = 0
	var contacts: int = 0
	var ign: bool = false

	if upgrades != null and is_instance_valid(upgrades):
		pv = float(upgrades.vitesse_px_s)
		vie = float(upgrades.duree_vie_s)
		pmask = int(upgrades.collision_mask)
		marge = float(upgrades.marge_raycast_px)
		largeur = float(upgrades.largeur_zone_scane)
		rays = int(upgrades.nombre_de_rayon_dans_zone_scane)
		contacts = int(upgrades.contacts_avant_destruction)
		ign = bool(upgrades.ignorer_meme_cible)

	_set_val("proj", "Vitesse", "%.0f px/s" % pv)
	_set_val("proj", "Vie", "%.2fs" % vie)
	_set_val("proj", "Mask", str(pmask))
	_set_val("proj", "Marge ray", "%.2fpx" % marge)
	_set_val("proj", "Largeur zone scan", "%.1fpx" % largeur)
	_set_val("proj", "Rays dans zone", str(rays))
	_set_val("proj", "Contacts avant destroy", str(contacts))
	_set_val("proj", "Ignore même cible", "Oui" if ign else "Non")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			ui_visible = not ui_visible
			_dbg("toggle key=%s -> ui=%s" % [str(toggle_key), str(_ui_visible)])
