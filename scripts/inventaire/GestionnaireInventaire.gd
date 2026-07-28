extends Node
class_name GestionnaireInventaire

signal inventaire_change
signal objet_ajoute(identifiant: StringName, quantite: int)
signal objet_retire(identifiant: StringName, quantite: int)

@export var objets_temporaires: Array[Dictionary] = []

var objets_par_identifiant: Dictionary = {}
var equipements_par_instance: Dictionary = {}

func _ready() -> void:
	add_to_group(&"gestionnaire_inventaire")
	for objet_temporaire: Dictionary in objets_temporaires:
		ajouter_depuis_payload(objet_temporaire)

func ajouter_depuis_payload(payload: Dictionary) -> void:
	var identifiant: StringName = payload.get("id", payload.get("item_id", &""))
	var quantite: int = maxi(int(payload.get("quantite", 1)), 0)
	if String(identifiant) == "" or quantite <= 0:
		return
	if _est_equipement_instance(payload):
		_ajouter_equipement_instance(identifiant, payload)
		return
	var entree: Dictionary = objets_par_identifiant.get(identifiant, {})
	if entree.is_empty():
		entree = {
			"identifiant": identifiant,
			"nom": String(payload.get("nom_affiche", identifiant)),
			"icone": payload.get("icone", null),
			"quantite": 0,
			"type_item": int(payload.get("type_item", -1)),
			"type_loot": int(payload.get("type_loot", -1)),
			"scene": payload.get("scene", null),
			"donnees": Dictionary(payload.get("donnees", {})).duplicate(true)
		}
	elif String(payload.get("nom_affiche", "")).strip_edges() != "":
		entree["nom"] = String(payload.get("nom_affiche"))
	if payload.get("icone", null) != null:
		entree["icone"] = payload.get("icone")
	entree["quantite"] = int(entree.get("quantite", 0)) + quantite
	objets_par_identifiant[identifiant] = entree
	objet_ajoute.emit(identifiant, quantite)
	inventaire_change.emit()

func _est_equipement_instance(payload: Dictionary) -> bool:
	var donnees: Dictionary = Dictionary(payload.get("donnees", {}))
	return int(payload.get("type_item", -1)) == Loot.TypeItem.EQUIPEMENT and String(donnees.get("identifiant_instance", &"")) != ""

func _ajouter_equipement_instance(identifiant: StringName, payload: Dictionary) -> void:
	var donnees: Dictionary = Dictionary(payload.get("donnees", {})).duplicate(true)
	var identifiant_instance: StringName = donnees.get("identifiant_instance", &"")
	if equipements_par_instance.has(identifiant_instance):
		return
	equipements_par_instance[identifiant_instance] = {
		"identifiant": identifiant,
		"identifiant_instance": identifiant_instance,
		"nom": String(payload.get("nom_affiche", identifiant)),
		"icone": payload.get("icone", null),
		"quantite": 1,
		"type_item": Loot.TypeItem.EQUIPEMENT,
		"type_loot": int(payload.get("type_loot", -1)),
		"scene": payload.get("scene", null),
		"donnees": donnees
	}
	objet_ajoute.emit(identifiant, 1)
	inventaire_change.emit()

func ajouter_objet(identifiant: StringName, nom: String, quantite: int, icone: Texture2D = null, type_item: int = -1, donnees: Dictionary = {}) -> void:
	ajouter_depuis_payload({
		"id": identifiant,
		"nom_affiche": nom,
		"quantite": quantite,
		"icone": icone,
		"type_item": type_item,
		"donnees": donnees
	})

func retirer_objet(identifiant: StringName, quantite: int) -> int:
	var quantite_demandee: int = maxi(quantite, 0)
	if quantite_demandee <= 0:
		return 0
	var quantite_retiree: int = _retirer_equipements(identifiant, quantite_demandee)
	var quantite_restante: int = quantite_demandee - quantite_retiree
	if quantite_restante > 0 and objets_par_identifiant.has(identifiant):
		var entree: Dictionary = objets_par_identifiant[identifiant]
		var quantite_disponible: int = int(entree.get("quantite", 0))
		var quantite_empilable: int = mini(quantite_disponible, quantite_restante)
		if quantite_disponible - quantite_empilable <= 0:
			objets_par_identifiant.erase(identifiant)
		else:
			entree["quantite"] = quantite_disponible - quantite_empilable
			objets_par_identifiant[identifiant] = entree
		quantite_retiree += quantite_empilable
	if quantite_retiree > 0:
		objet_retire.emit(identifiant, quantite_retiree)
		inventaire_change.emit()
	return quantite_retiree

func _retirer_equipements(identifiant: StringName, quantite: int) -> int:
	var quantite_retiree: int = 0
	var instances: Array[StringName] = []
	for identifiant_instance: Variant in equipements_par_instance:
		var equipement: Dictionary = equipements_par_instance[identifiant_instance]
		if equipement.get("identifiant", &"") == identifiant:
			instances.append(identifiant_instance)
	instances.sort()
	for identifiant_instance: StringName in instances:
		if quantite_retiree >= quantite:
			break
		equipements_par_instance.erase(identifiant_instance)
		quantite_retiree += 1
	return quantite_retiree

func obtenir_quantite(identifiant: StringName) -> int:
	var quantite: int = int((objets_par_identifiant[identifiant] as Dictionary).get("quantite", 0)) if objets_par_identifiant.has(identifiant) else 0
	for equipement: Dictionary in equipements_par_instance.values():
		if equipement.get("identifiant", &"") == identifiant:
			quantite += 1
	return quantite

func obtenir_objet(identifiant: StringName) -> Dictionary:
	for equipement: Dictionary in equipements_par_instance.values():
		if equipement.get("identifiant", &"") == identifiant:
			return equipement.duplicate(true)
	return Dictionary(objets_par_identifiant.get(identifiant, {})).duplicate(true)

func obtenir_equipement_instance(identifiant_instance: StringName) -> Dictionary:
	return Dictionary(equipements_par_instance.get(identifiant_instance, {})).duplicate(true)

func retirer_equipement_instance(identifiant_instance: StringName) -> Dictionary:
	var equipement: Dictionary = obtenir_equipement_instance(identifiant_instance)
	if equipement.is_empty():
		return {}
	equipements_par_instance.erase(identifiant_instance)
	objet_retire.emit(equipement.get("identifiant", &""), 1)
	inventaire_change.emit()
	return equipement

func mettre_a_jour_equipement_instance(identifiant_instance: StringName, nouvelles_donnees: Dictionary) -> bool:
	if not equipements_par_instance.has(identifiant_instance):
		return false
	var equipement: Dictionary = equipements_par_instance[identifiant_instance]
	equipement["donnees"] = nouvelles_donnees.duplicate(true)
	equipements_par_instance[identifiant_instance] = equipement
	inventaire_change.emit()
	return true

func obtenir_objets() -> Array[Dictionary]:
	var objets: Array[Dictionary] = []
	for identifiant: Variant in objets_par_identifiant:
		objets.append(Dictionary(objets_par_identifiant[identifiant]).duplicate(true))
	for equipement: Dictionary in equipements_par_instance.values():
		objets.append(equipement.duplicate(true))
	objets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("nom", "")) < String(b.get("nom", "")))
	return objets

func obtenir_quantites() -> Dictionary:
	var quantites: Dictionary = {}
	for identifiant: Variant in objets_par_identifiant:
		quantites[identifiant] = int((objets_par_identifiant[identifiant] as Dictionary).get("quantite", 0))
	for equipement: Dictionary in equipements_par_instance.values():
		var identifiant: StringName = equipement.get("identifiant", &"")
		quantites[identifiant] = int(quantites.get(identifiant, 0)) + 1
	return quantites

func vider() -> void:
	if objets_par_identifiant.is_empty() and equipements_par_instance.is_empty():
		return
	objets_par_identifiant.clear()
	equipements_par_instance.clear()
	inventaire_change.emit()
