extends Node
class_name TableCuisine

signal contenu_change

const NOMBRE_SLOTS: int = 3

var objets_dans_slots: Array[Dictionary] = []

func _ready() -> void:
	reinitialiser()

func reinitialiser() -> void:
	objets_dans_slots.clear()
	for index: int in NOMBRE_SLOTS:
		objets_dans_slots.append({})
	contenu_change.emit()

func obtenir_objet(index_slot: int) -> Dictionary:
	if not _index_est_valide(index_slot):
		return {}
	return objets_dans_slots[index_slot].duplicate(true)

func deposer_objet(index_slot: int, objet: Dictionary) -> bool:
	if not _index_est_valide(index_slot) or not objets_dans_slots[index_slot].is_empty():
		return false
	var identifiant: StringName = objet.get("identifiant", &"")
	if String(identifiant).is_empty():
		return false
	var objet_stocke: Dictionary = objet.duplicate(true)
	objet_stocke["quantite"] = 1
	objets_dans_slots[index_slot] = objet_stocke
	contenu_change.emit()
	return true

func retirer_objet(index_slot: int) -> Dictionary:
	if not _index_est_valide(index_slot):
		return {}
	var objet: Dictionary = objets_dans_slots[index_slot].duplicate(true)
	if objet.is_empty():
		return {}
	objets_dans_slots[index_slot] = {}
	contenu_change.emit()
	return objet

func obtenir_contenu_total() -> Dictionary:
	var contenu: Dictionary = {}
	for objet: Dictionary in objets_dans_slots:
		if objet.is_empty():
			continue
		var identifiant: StringName = objet.get("identifiant", &"")
		if String(identifiant).is_empty():
			continue
		contenu[identifiant] = int(contenu.get(identifiant, 0)) + 1
	return contenu

func extraire_tous_les_objets() -> Array[Dictionary]:
	var objets: Array[Dictionary] = []
	for objet: Dictionary in objets_dans_slots:
		if not objet.is_empty():
			objets.append(objet.duplicate(true))
	reinitialiser()
	return objets

func _index_est_valide(index_slot: int) -> bool:
	return index_slot >= 0 and index_slot < NOMBRE_SLOTS
