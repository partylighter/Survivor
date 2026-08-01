extends RefCounted
class_name TableCraftInventaire

const NOMBRE_SLOTS: int = 3

var objets_dans_slots: Array[Dictionary] = [{}, {}, {}]

func deposer(index_slot: int, objet: Dictionary) -> bool:
	if index_slot < 0 or index_slot >= NOMBRE_SLOTS or not objets_dans_slots[index_slot].is_empty() or objet.is_empty():
		return false
	var objet_unitaire: Dictionary = objet.duplicate(true)
	objet_unitaire["quantite"] = 1
	objets_dans_slots[index_slot] = objet_unitaire
	return true

func retirer(index_slot: int) -> Dictionary:
	if index_slot < 0 or index_slot >= NOMBRE_SLOTS:
		return {}
	var objet: Dictionary = objets_dans_slots[index_slot].duplicate(true)
	objets_dans_slots[index_slot] = {}
	return objet

func obtenir(index_slot: int) -> Dictionary:
	if index_slot < 0 or index_slot >= NOMBRE_SLOTS:
		return {}
	return objets_dans_slots[index_slot].duplicate(true)

func obtenir_quantites() -> Dictionary:
	var quantites: Dictionary = {}
	for objet: Dictionary in objets_dans_slots:
		if objet.is_empty():
			continue
		var identifiant: StringName = objet.get("identifiant", &"")
		quantites[identifiant] = int(quantites.get(identifiant, 0)) + 1
	return quantites

func trouver_premier_slot_vide() -> int:
	for index: int in NOMBRE_SLOTS:
		if objets_dans_slots[index].is_empty():
			return index
	return -1

func vider() -> void:
	for index: int in NOMBRE_SLOTS:
		objets_dans_slots[index] = {}

func est_vide() -> bool:
	for objet: Dictionary in objets_dans_slots:
		if not objet.is_empty():
			return false
	return true
