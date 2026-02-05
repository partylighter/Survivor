extends CanvasLayer
class_name LootDisplayer

@export var actif: bool = true
@export var ui_visible: bool = true : set = set_ui_visible, get = get_ui_visible
@export_node_path("GestionnaireLoot") var chemin_loot: NodePath
@export var position_loot_ui: Vector2 = Vector2(16, 16)

@export var noms_par_id: Dictionary = {
	"carburant_1": "Fuel I",
	"carburant_2": "Fuel II",
	"carburant_3": "Fuel III",
	"upgrade_carburant_1": "Fuel I",
	"upgrade_carburant_2": "Fuel II",
	"upgrade_carburant_3": "Fuel III"
}

var _ui_visible: bool = true
var loot_ref: GestionnaireLoot = null
var lbl_loot: Label = null

func _ready() -> void:
	_ui_visible = ui_visible
	set_ui_visible(_ui_visible)

	loot_ref = get_node_or_null(chemin_loot) as GestionnaireLoot

	lbl_loot = Label.new()
	lbl_loot.name = "LblLoot"
	lbl_loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_loot.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl_loot.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_loot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_loot.size_flags_vertical = Control.SIZE_FILL
	lbl_loot.custom_minimum_size = Vector2(280, 180)
	add_child(lbl_loot)

	var c := lbl_loot as Control
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = position_loot_ui

	_attach_loot_signal()
	_refresh_ui()

func _attach_loot_signal() -> void:
	if loot_ref == null or not is_instance_valid(loot_ref):
		return
	if loot_ref.has_signal("loot_change") and not loot_ref.loot_change.is_connected(_on_loot_change):
		loot_ref.loot_change.connect(_on_loot_change)

func _on_loot_change() -> void:
	if not actif:
		return
	_refresh_ui()

func _refresh_ui() -> void:
	if not actif:
		return

	if loot_ref == null or not is_instance_valid(loot_ref):
		loot_ref = get_node_or_null(chemin_loot) as GestionnaireLoot
		if loot_ref == null:
			if lbl_loot:
				lbl_loot.text = "Loot: (GestionnaireLoot introuvable)"
			return
		_attach_loot_signal()

	if lbl_loot == null or not is_instance_valid(lbl_loot):
		return

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
		lignes.append("%s : %d" % [String(it["nom"]), int(it["q"])])

	lbl_loot.text = "Aucun loot récupéré" if lignes.is_empty() else "\n".join(lignes)

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

func set_ui_visible(v: bool) -> void:
	_ui_visible = v
	visible = v

func get_ui_visible() -> bool:
	return _ui_visible

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			set_ui_visible(not _ui_visible)
