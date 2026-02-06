extends CanvasLayer
class_name LaboloMenu

const GROUPE_UPG_TIR: StringName = &"upg_arme_tir"
var upg_tir_ref: Node = null
const GROUPE_UPG_CONTACT: StringName = &"upg_arme_contact"
var upg_contact_ref: Node = null

const GROUPE_LOOT: StringName = &"gestionnaire_loot"
const ACTION_MENU_LABO: StringName = &"menu_labo"

@export var debug_labolo: bool = false

@export_node_path("GridContainer") var chemin_grille: NodePath
@export_node_path("EmplacementDepotArme") var chemin_emplacement_tir: NodePath
@export_node_path("EmplacementDepotArme") var chemin_emplacement_contact: NodePath

@export var scene_cellule: PackedScene
@export var prefixes_affiches: PackedStringArray = ["upg_", "upgrade_"]

var loot_ref: Node = null

var _refresh_pending: bool = false
var _loot_sig_connected: bool = false

@onready var grille: GridContainer = get_node_or_null(chemin_grille) as GridContainer
@onready var emplacement_tir: EmplacementDepotArme = get_node_or_null(chemin_emplacement_tir) as EmplacementDepotArme
@onready var emplacement_contact: EmplacementDepotArme = get_node_or_null(chemin_emplacement_contact) as EmplacementDepotArme

func _ready() -> void:
	visible = false

	if grille == null:
		_d("ERREUR: grille introuvable (chemin_grille=%s)" % [str(chemin_grille)])
	if scene_cellule == null:
		_d("WARN: scene_cellule = null (tu dois la set dans l'inspecteur)")
	if emplacement_tir == null:
		_d("WARN: emplacement_tir introuvable (chemin=%s)" % [str(chemin_emplacement_tir)])
	if emplacement_contact == null:
		_d("WARN: emplacement_contact introuvable (chemin=%s)" % [str(chemin_emplacement_contact)])

	if emplacement_tir:
		emplacement_tir.item_depose.connect(_on_item_depose)
	if emplacement_contact:
		emplacement_contact.item_depose.connect(_on_item_depose)

	_trouver_loot()

	if get_tree():
		get_tree().node_added.connect(_on_node_added)
func _trouver_upg_contact() -> void:
	if upg_contact_ref != null and is_instance_valid(upg_contact_ref):
		return
	upg_contact_ref = get_tree().get_first_node_in_group(GROUPE_UPG_CONTACT)

func _trouver_upg_tir() -> void:
	if upg_tir_ref != null and is_instance_valid(upg_tir_ref):
		return
	upg_tir_ref = get_tree().get_first_node_in_group(GROUPE_UPG_TIR)

func _appliquer_upgrade_labo(type_emplacement: int, id_item: StringName, quantite: int) -> void:
	var manager: Node = null

	if emplacement_tir and type_emplacement == int(emplacement_tir.type_emplacement):
		_trouver_upg_tir()
		manager = upg_tir_ref

	elif emplacement_contact and type_emplacement == int(emplacement_contact.type_emplacement):
		_trouver_upg_contact()
		manager = upg_contact_ref

	if manager == null or not is_instance_valid(manager):
		return

	if manager.has_method("ajouter_upgrade_par_id"):
		manager.call("ajouter_upgrade_par_id", id_item, quantite)

	if manager.has_method("re_appliquer"):
		manager.call("re_appliquer")

func _exit_tree() -> void:
	if get_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	_detacher_loot()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(ACTION_MENU_LABO):
		toggle()

func _on_node_added(n: Node) -> void:
	if loot_ref != null and is_instance_valid(loot_ref):
		return
	if n != null and n.is_in_group(GROUPE_LOOT):
		_attacher_loot(n)

func _trouver_loot() -> void:
	if loot_ref != null and is_instance_valid(loot_ref):
		return

	var n := get_tree().get_first_node_in_group(GROUPE_LOOT)
	if n != null:
		_attacher_loot(n)
	else:
		_d("Loot introuvable (group=%s). Attente via node_added..." % [String(GROUPE_LOOT)])

func _attacher_loot(n: Node) -> void:
	if n == null:
		return
	if loot_ref == n:
		return

	_detacher_loot()
	loot_ref = n

	if not loot_ref.tree_exited.is_connected(_on_loot_quitte_scene):
		loot_ref.tree_exited.connect(_on_loot_quitte_scene)

	# CONNECT SIGNAL LOOT_CHANGE
	_loot_sig_connected = false
	if loot_ref.has_signal("loot_change"):
		var cb := Callable(self, "_on_loot_change")
		if not loot_ref.is_connected("loot_change", cb):
			loot_ref.connect("loot_change", cb)
		_loot_sig_connected = true
	else:
		_d("WARN: loot_ref n'a pas le signal loot_change -> pas de refresh temps réel")

	_d("Loot attaché: %s" % [_node_tag(loot_ref)])

func _detacher_loot() -> void:
	if loot_ref != null and is_instance_valid(loot_ref):
		if loot_ref.tree_exited.is_connected(_on_loot_quitte_scene):
			loot_ref.tree_exited.disconnect(_on_loot_quitte_scene)

		# Deconnecte SIGNAL LOOT_CHANGE
		if loot_ref.has_signal("loot_change"):
			var cb := Callable(self, "_on_loot_change")
			if loot_ref.is_connected("loot_change", cb):
				loot_ref.disconnect("loot_change", cb)

	loot_ref = null
	_loot_sig_connected = false

func _on_loot_change() -> void:
	if not visible:
		return
	if _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_refresh_grille_deferred")

func _refresh_grille_deferred() -> void:
	_refresh_pending = false
	rafraichir_grille()

func _on_loot_quitte_scene() -> void:
	_d("Loot a quitté l'arbre -> reset ref")
	loot_ref = null

func ouvrir() -> void:
	visible = true
	_d("OUVRIR menu")
	_trouver_loot()
	rafraichir_grille()
	_set_inputs_enabled(false)

func fermer() -> void:
	visible = false
	_d("FERMER menu")
	_set_inputs_enabled(true)

func _set_inputs_enabled(enabled: bool) -> void:
	for n in get_tree().get_nodes_in_group(&"inputs_jeu"):
		if not is_instance_valid(n):
			continue
		n.set_process(enabled)
		n.set_physics_process(enabled)

func toggle() -> void:
	if visible:
		fermer()
	else:
		ouvrir()

func rafraichir_grille() -> void:
	if grille == null:
		_d("rafraichir_grille: grille=null")
		return
	if scene_cellule == null:
		_d("rafraichir_grille: scene_cellule=null")
		return

	_trouver_loot()
	if loot_ref == null or not is_instance_valid(loot_ref):
		_d("rafraichir_grille: loot_ref manquant (group=%s)" % [String(GROUPE_LOOT)])
		return

	if not loot_ref.has_method("get_stats_loot"):
		_d("rafraichir_grille: loot_ref n'a pas get_stats_loot() -> %s" % [_node_tag(loot_ref)])
		return

	for c in grille.get_children():
		grille.remove_child(c)
		c.queue_free()

	var d: Dictionary = loot_ref.call("get_stats_loot")

	var total_ids := d.size()
	var affiches := 0
	var skip_zero := 0
	var skip_prefix := 0

	for k in d.keys():
		var id: StringName = k as StringName
		var q: int = int(d[k])

		if q <= 0:
			skip_zero += 1
			continue
		if not _match_prefix(String(id)):
			skip_prefix += 1
			continue

		var nom: String = ""
		if loot_ref.has_method("get_nom_affiche_pour_id"):
			nom = String(loot_ref.call("get_nom_affiche_pour_id", id))

		var cell := scene_cellule.instantiate()
		if cell == null:
			continue

		grille.add_child(cell)

		if cell.has_method("set_donnees"):
			cell.call("set_donnees", id, nom, q)
		elif cell.has_method("set_data"):
			cell.call("set_data", id, nom, q)

		affiches += 1

	_d("Grille: total_ids=%d affiches=%d skip_zero=%d skip_prefix=%d prefixes=%s" % [
		total_ids, affiches, skip_zero, skip_prefix, str(prefixes_affiches)
	])

func _match_prefix(s: String) -> bool:
	if prefixes_affiches.is_empty():
		return true
	for p in prefixes_affiches:
		if s.begins_with(String(p)):
			return true
	return false

func _on_item_depose(type_emplacement: int, id_item: StringName, _quantite: int) -> void:
	var slot := "?"
	if emplacement_tir and type_emplacement == int(emplacement_tir.type_emplacement):
		slot = "TIR"
	elif emplacement_contact and type_emplacement == int(emplacement_contact.type_emplacement):
		slot = "CONTACT"

	_trouver_loot()
	if loot_ref == null or not is_instance_valid(loot_ref):
		if debug_labolo:
			print("[Labolo] DROP REFUS: loot_ref manquant")
		return

	if not loot_ref.has_method("consommer_loot"):
		if debug_labolo:
			print("[Labolo] DROP REFUS: loot_ref n'a pas consommer_loot()")
		return

	# Par défaut: 1 item consommé par drop 
	var a_prendre: int = 1
	var pris: int = int(loot_ref.call("consommer_loot", id_item, a_prendre))

	if pris <= 0:
		if debug_labolo:
			print("[Labolo] DROP: rien consommé (stock vide?) slot=", slot, " id=", String(id_item))
		return

	if debug_labolo:
		print("[Labolo] DROP OK: slot=", slot, " id=", String(id_item), " pris=", pris)

	# TODO: ici on branchera l'application de l'upgrade sur l'arme
	_appliquer_upgrade_labo(type_emplacement, id_item, pris)

	rafraichir_grille()

func _d(msg: String) -> void:
	if debug_labolo:
		print("[Labolo] ", msg)

func _node_tag(n: Node) -> String:
	if n == null:
		return "null"
	return "%s:<%s#%d>" % [n.name, n.get_class(), n.get_instance_id()]
