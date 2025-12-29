extends PanelContainer
class_name EmplacementDepotArme

signal item_depose(type_emplacement: int, id_item: StringName, quantite: int)

enum TypeEmplacement { TIR, CONTACT }

@export var type_emplacement: TypeEmplacement = TypeEmplacement.TIR
@export var titre: String = "ARME"

@export var debug_depot: bool = false
@export var accepter_prefixes: PackedStringArray = [] # vide = tout accepter

@onready var lbl_titre: Label = $Colonne/Titre
@onready var lbl_indice: Label = $Colonne/Indice

func _ready() -> void:
	if lbl_titre:
		lbl_titre.text = titre
	_set_hint("Dépose un item ici")

func _can_drop_data(_pos: Vector2, data) -> bool:
	var ok := _verifier_data(data)
	if debug_depot:
		print("[DepotArme] can_drop=", ok, " slot=", _nom_slot(), " data=", _resume_data(data))
	return ok

func _drop_data(_pos: Vector2, data) -> void:
	if not _verifier_data(data):
		if debug_depot:
			print("[DepotArme] DROP REFUSÉ slot=", _nom_slot(), " data=", _resume_data(data))
		_set_hint("Item invalide")
		return

	var id: StringName = data["id_item"]
	var q: int = int(data["quantite"])

	if debug_depot:
		print("[DepotArme] DROP OK slot=", _nom_slot(), " id=", id, " q=", q)

	_set_hint("OK: " + String(id))
	emit_signal("item_depose", int(type_emplacement), id, q)

func _verifier_data(data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("id_item") or not data.has("quantite"):
		return false

	var id: StringName = data.get("id_item", &"")
	var q: int = int(data.get("quantite", 0))

	if String(id) == "" or q <= 0:
		return false

	if not accepter_prefixes.is_empty():
		var s := String(id)
		var prefix_ok := false
		for p in accepter_prefixes:
			if s.begins_with(String(p)):
				prefix_ok = true
				break
		if not prefix_ok:
			return false

	return true

func _nom_slot() -> String:
	return ("TIR" if type_emplacement == TypeEmplacement.TIR else "CONTACT") + " (" + titre + ")"

func _resume_data(data) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return str(typeof(data))
	var id := StringName(data.get("id_item", &""))
	var q := int(data.get("quantite", -1))
	return "{id_item=%s, quantite=%d, keys=%s}" % [String(id), q, str(data.keys())]

func _set_hint(t: String) -> void:
	if lbl_indice:
		lbl_indice.text = t
