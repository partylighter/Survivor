extends Node
class_name TableForge

signal table_changee

const NOMBRE_SLOTS: int = 9
const LARGEUR_GRILLE: int = 3
const HAUTEUR_GRILLE: int = 3

var objets_dans_slots: Array[Dictionary] = []

func _ready() -> void:
	reinitialiser()

func ajouter_objet_dans_slot(index_slot: int, objet: Dictionary) -> bool:
	if index_slot < 0 or index_slot >= NOMBRE_SLOTS:
		return false
	var identifiant: StringName = objet.get("identifiant", &"")
	if String(identifiant) == "" or int(objet.get("quantite", 0)) <= 0:
		return false
	var objet_present: Dictionary = objets_dans_slots[index_slot]
	if not objet_present.is_empty() and objet_present.get("identifiant", &"") != identifiant:
		return false
	if objet_present.is_empty():
		objets_dans_slots[index_slot] = objet.duplicate(true)
	else:
		objet_present["quantite"] = int(objet_present.get("quantite", 0)) + int(objet.get("quantite", 0))
		objets_dans_slots[index_slot] = objet_present
	table_changee.emit()
	return true

func retirer_objet_du_slot(index_slot: int) -> Dictionary:
	if index_slot < 0 or index_slot >= NOMBRE_SLOTS:
		return {}
	var objet: Dictionary = objets_dans_slots[index_slot].duplicate(true)
	objets_dans_slots[index_slot] = {}
	table_changee.emit()
	return objet

func deplacer_objet(index_depart: int, index_arrivee: int) -> void:
	if index_depart < 0 or index_depart >= NOMBRE_SLOTS or index_arrivee < 0 or index_arrivee >= NOMBRE_SLOTS:
		return
	if objets_dans_slots[index_depart].is_empty() or not objets_dans_slots[index_arrivee].is_empty():
		return
	objets_dans_slots[index_arrivee] = objets_dans_slots[index_depart]
	objets_dans_slots[index_depart] = {}
	table_changee.emit()

func obtenir_objet_du_slot(index_slot: int) -> Dictionary:
	if index_slot < 0 or index_slot >= NOMBRE_SLOTS:
		return {}
	return objets_dans_slots[index_slot].duplicate(true)

func obtenir_contenu_total() -> Dictionary:
	var contenu: Dictionary = {}
	for objet: Dictionary in objets_dans_slots:
		if objet.is_empty():
			continue
		var identifiant: StringName = objet.get("identifiant", &"")
		contenu[identifiant] = int(contenu.get(identifiant, 0)) + int(objet.get("quantite", 0))
	return contenu

func trouver_premier_slot_vide() -> int:
	for index: int in NOMBRE_SLOTS:
		if objets_dans_slots[index].is_empty():
			return index
	return -1

func consommer_un_objet_par_slot_occupe() -> void:
	for index: int in objets_dans_slots.size():
		var objet: Dictionary = objets_dans_slots[index]
		if objet.is_empty():
			continue
		var quantite_restante: int = int(objet.get("quantite", 0)) - 1
		if quantite_restante <= 0:
			objets_dans_slots[index] = {}
		else:
			objet["quantite"] = quantite_restante
			objets_dans_slots[index] = objet
	table_changee.emit()

func extraire_tous_les_objets() -> Array[Dictionary]:
	var objets: Array[Dictionary] = []
	for objet: Dictionary in objets_dans_slots:
		if not objet.is_empty():
			objets.append(objet.duplicate(true))
	reinitialiser()
	return objets

func reinitialiser() -> void:
	objets_dans_slots.clear()
	for index: int in NOMBRE_SLOTS:
		objets_dans_slots.append({})
	table_changee.emit()
