extends CanvasLayer
class_name LootDisplayer

@export var actif: bool = true
@export var debug_enabled: bool = false

var _ui_visible: bool = true
@export var ui_visible: bool = true:
	set(v):
		_ui_visible = v
		_apply_ui_visible()
	get:
		return _ui_visible

@export_node_path("GestionnaireLoot") var chemin_loot: NodePath

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(16, 16)
@export var ui_largeur_min_px: float = 360.0
@export_range(8, 64, 1) var ui_taille_police: int = 14
@export var ui_couleur_fond: Color = Color(0, 0, 0, 0.55)
@export var ui_couleur_texte: Color = Color(1, 1, 1, 0.92)
@export_range(0, 64, 1) var ui_espace_lignes: int = 4
@export_range(0, 32, 1) var ui_max_items_affiches: int = 24

@export_group("Raccourci")
@export var toggle_key: Key = KEY_F12

@export_group("Noms")
@export var noms_par_id: Dictionary = {
	"carburant_1": "Fuel I",
	"carburant_2": "Fuel II",
	"carburant_3": "Fuel III",
	"upgrade_carburant_1": "Fuel I",
	"upgrade_carburant_2": "Fuel II",
	"upgrade_carburant_3": "Fuel III"
}

var loot_ref: GestionnaireLoot = null

var _panel: Panel
var _margin: MarginContainer
var _root: VBoxContainer
var _stylebox: StyleBoxFlat
var _title: Label
var _sub: Label
var _list: VBoxContainer

var _items_labels: Array[Label] = []

func _ready() -> void:
	_ui_visible = ui_visible
	loot_ref = get_node_or_null(chemin_loot) as GestionnaireLoot
	_creer_ui()
	_appliquer_style()
	_apply_ui_visible()
	_attach_loot_signal()
	_refresh_ui()

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[LootDisplayer] ", msg)

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

	_list = VBoxContainer.new()
	_root.add_child(_list)
	_list.add_theme_constant_override("separation", 0)

	_ensure_item_labels(ui_max_items_affiches)

func _ensure_item_labels(n: int) -> void:
	n = max(n, 1)
	while _items_labels.size() < n:
		var l := Label.new()
		l.text = ""
		l.visible = false
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(l)
		_items_labels.append(l)

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

	_title.text = "LOOT"
	_title.add_theme_font_size_override("font_size", ui_taille_police + 3)
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))

	_sub.text = "F12 pour afficher/masquer"
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

func _attach_loot_signal() -> void:
	if loot_ref == null or not is_instance_valid(loot_ref):
		return
	if loot_ref.has_signal("loot_change") and not loot_ref.loot_change.is_connected(_on_loot_change):
		loot_ref.loot_change.connect(_on_loot_change)

func _on_loot_change() -> void:
	if not actif:
		return
	_refresh_ui()

func _process(_dt: float) -> void:
	if not actif or _panel == null or not _panel.visible:
		return
	_panel.position = ui_position

func _refresh_ui() -> void:
	if not actif:
		return

	_ensure_item_labels(ui_max_items_affiches)

	if loot_ref == null or not is_instance_valid(loot_ref):
		loot_ref = get_node_or_null(chemin_loot) as GestionnaireLoot
		if loot_ref == null:
			_set_lines(["Loot: (GestionnaireLoot introuvable)"])
			return
		_attach_loot_signal()

	var stats_src: Dictionary = {}
	if loot_ref.has_method("get_stats_loot_affichage"):
		stats_src = loot_ref.call("get_stats_loot_affichage")
	else:
		stats_src = loot_ref.get_stats_loot()

	var nom_to_q: Dictionary = {}
	for k in stats_src.keys():
		var q: int = int(stats_src.get(k, 0))
		if q <= 0:
			continue
		var nom: String = _nom_affiche(k)
		nom_to_q[nom] = int(nom_to_q.get(nom, 0)) + q

	var items: Array = []
	for nom in nom_to_q.keys():
		items.append({"nom": String(nom), "q": int(nom_to_q[nom])})
	items.sort_custom(Callable(self, "_sort_items"))

	var lignes: Array[String] = []

	if loot_ref.has_method("get_carburant_stocke"):
		var c: float = float(loot_ref.get_carburant_stocke())
		if c > 0.0:
			lignes.append("Carburant stocké : " + str(snappedf(c, 0.1)))

	for it in items:
		if lignes.size() >= ui_max_items_affiches:
			break
		lignes.append("%s : %d" % [String(it["nom"]), int(it["q"])])

	if lignes.is_empty():
		lignes.append("Aucun loot récupéré")

	_set_lines(lignes)

func _set_lines(lines: Array[String]) -> void:
	for i in range(_items_labels.size()):
		var l := _items_labels[i]
		if i < lines.size():
			l.text = lines[i]
			l.visible = true
		else:
			l.text = ""
			l.visible = false

func _sort_items(a: Dictionary, b: Dictionary) -> bool:
	var qa: int = int(a.get("q", 0))
	var qb: int = int(b.get("q", 0))
	if qa != qb:
		return qa > qb
	return String(a.get("nom", "")) < String(b.get("nom", ""))

func _nom_affiche(id_any) -> String:
	if loot_ref != null and is_instance_valid(loot_ref) and loot_ref.has_method("get_nom_affiche_pour_id"):
		var r = loot_ref.call("get_nom_affiche_pour_id", id_any)
		if typeof(r) == TYPE_STRING and String(r) != "":
			return String(r)

	var sid: String = String(id_any)
	if noms_par_id.has(sid):
		return String(noms_par_id[sid])
	return sid

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			ui_visible = not ui_visible
			_dbg("toggle key=%s -> ui=%s" % [str(toggle_key), str(_ui_visible)])
