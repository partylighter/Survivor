extends Node
class_name GestionnaireInventaire

const SCENE_EQUIPEMENT_AU_SOL: PackedScene = preload("res://scenes/objets/equipement_au_sol.tscn")
const DUREE_VERROUILLAGE_JET: float = 0.4

signal inventaire_change
signal objet_ajoute(identifiant: StringName, quantite: int)
signal objet_retire(identifiant: StringName, quantite: int)

@export var objets_temporaires: Array[Dictionary] = []
@export var ressources_temporaires: Array[LootItemEntry] = []

var objets_par_identifiant: Dictionary = {}
var equipements_par_instance: Dictionary = {}

func _ready() -> void:
	add_to_group(&"gestionnaire_inventaire")
	for objet_temporaire: Dictionary in objets_temporaires:
		ajouter_depuis_payload(objet_temporaire)
	for ressource_temporaire: LootItemEntry in ressources_temporaires:
		_ajouter_depuis_ressource(ressource_temporaire)

func _ajouter_depuis_ressource(ressource: LootItemEntry) -> void:
	if ressource == null or String(ressource.item_id).is_empty():
		return
	var donnees: Dictionary = {"chemin_definition": ressource.resource_path}
	if ressource.type_item == Loot.TypeItem.EQUIPEMENT:
		donnees = DonneesInstanceEquipement.creer(ressource.item_id, ressource.resource_path, &"correcte", {})
	ajouter_objet(ressource.item_id, ressource.nom_affiche, 1, ressource.icone, ressource.type_item, donnees)

func ajouter_depuis_payload(payload: Dictionary) -> bool:
	var identifiant: StringName = payload.get("id", payload.get("item_id", payload.get("identifiant", &"")))
	var quantite: int = maxi(int(payload.get("quantite", 1)), 0)
	if String(identifiant) == "" or quantite <= 0:
		return false
	var nom_objet: String = _obtenir_nom_payload(payload, identifiant)
	if _est_equipement_instance(payload):
		return _ajouter_equipement_instance(identifiant, nom_objet, payload)
	if int(payload.get("type_item", -1)) == Loot.TypeItem.EQUIPEMENT:
		return false
	var entree: Dictionary = objets_par_identifiant.get(identifiant, {})
	if entree.is_empty():
		entree = {
			"identifiant": identifiant,
			"nom": nom_objet,
			"icone": payload.get("icone", null),
			"quantite": 0,
			"type_item": int(payload.get("type_item", -1)),
			"type_loot": int(payload.get("type_loot", -1)),
			"scene": payload.get("scene", null),
			"donnees": Dictionary(payload.get("donnees", {})).duplicate(true)
		}
	elif _payload_contient_nom(payload):
		entree["nom"] = nom_objet
	if payload.get("icone", null) != null:
		entree["icone"] = payload.get("icone")
	entree["quantite"] = int(entree.get("quantite", 0)) + quantite
	objets_par_identifiant[identifiant] = entree
	objet_ajoute.emit(identifiant, quantite)
	inventaire_change.emit()
	return true

func _est_equipement_instance(payload: Dictionary) -> bool:
	var donnees: Dictionary = Dictionary(payload.get("donnees", {}))
	return int(payload.get("type_item", -1)) == Loot.TypeItem.EQUIPEMENT and String(donnees.get("identifiant_instance", &"")) != ""

func _ajouter_equipement_instance(identifiant: StringName, nom_objet: String, payload: Dictionary) -> bool:
	var donnees: Dictionary = Dictionary(payload.get("donnees", {})).duplicate(true)
	var identifiant_instance: StringName = donnees.get("identifiant_instance", &"")
	var chemin_definition: String = String(donnees.get("chemin_definition", ""))
	var definition: LootItemEntry = load(chemin_definition) as LootItemEntry if not chemin_definition.is_empty() else null
	if definition == null or definition.item_id != identifiant or not DonneesInstanceEquipement.est_valide_pour(donnees, definition):
		return false
	if equipements_par_instance.has(identifiant_instance):
		return false
	equipements_par_instance[identifiant_instance] = {
		"identifiant": identifiant,
		"identifiant_instance": identifiant_instance,
		"chemin_definition": String(donnees.get("chemin_definition", "")),
		"nom": nom_objet,
		"icone": payload.get("icone", null),
		"quantite": 1,
		"type_item": Loot.TypeItem.EQUIPEMENT,
		"type_loot": int(payload.get("type_loot", -1)),
		"scene": payload.get("scene", null),
		"donnees": donnees
	}
	objet_ajoute.emit(identifiant, 1)
	inventaire_change.emit()
	return true

func _obtenir_nom_payload(payload: Dictionary, identifiant: StringName) -> String:
	var nom_objet: String = String(payload.get("nom_affiche", payload.get("nom", identifiant)))
	return String(identifiant) if nom_objet.strip_edges().is_empty() else nom_objet

func _payload_contient_nom(payload: Dictionary) -> bool:
	return not String(payload.get("nom_affiche", payload.get("nom", ""))).strip_edges().is_empty()

func ajouter_objet(identifiant: StringName, nom: String, quantite: int, icone: Texture2D = null, type_item: int = -1, donnees: Dictionary = {}) -> bool:
	return ajouter_depuis_payload({
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
	var quantite_retiree: int = 0
	if objets_par_identifiant.has(identifiant):
		var entree: Dictionary = objets_par_identifiant[identifiant]
		if int(entree.get("type_item", -1)) == Loot.TypeItem.EQUIPEMENT:
			return 0
		var quantite_disponible: int = int(entree.get("quantite", 0))
		var quantite_empilable: int = mini(quantite_disponible, quantite_demandee)
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
	var donnees_actuelles: Dictionary = Dictionary(equipement.get("donnees", {}))
	var chemin_definition: String = String(donnees_actuelles.get("chemin_definition", ""))
	var definition: LootItemEntry = load(chemin_definition) as LootItemEntry if not chemin_definition.is_empty() else null
	if nouvelles_donnees.get("identifiant_instance", &"") != identifiant_instance or not DonneesInstanceEquipement.est_valide_pour(nouvelles_donnees, definition):
		return false
	equipement["donnees"] = nouvelles_donnees.duplicate(true)
	equipements_par_instance[identifiant_instance] = equipement
	inventaire_change.emit()
	return true

func jeter_equipement(identifiant_instance: StringName, position_monde: Vector2) -> bool:
	var equipement: Dictionary = obtenir_equipement_instance(identifiant_instance)
	if equipement.is_empty() or get_tree().current_scene == null:
		return false
	var donnees: Dictionary = Dictionary(equipement.get("donnees", {})).duplicate(true)
	var chemin_definition: String = String(donnees.get("chemin_definition", ""))
	if chemin_definition.is_empty() or not ResourceLoader.exists(chemin_definition):
		return false
	var definition: LootItemEntry = load(chemin_definition) as LootItemEntry
	if definition == null or definition.type_item != Loot.TypeItem.EQUIPEMENT or definition.donnees_equipement == null or not DonneesInstanceEquipement.est_valide_pour(donnees, definition):
		return false
	var equipement_au_sol: EquipementAuSol = SCENE_EQUIPEMENT_AU_SOL.instantiate() as EquipementAuSol
	if equipement_au_sol == null:
		return false
	equipement_au_sol.configurer_depuis_instance(definition, donnees, int(equipement.get("type_loot", Loot.TypeLoot.C)))
	equipement_au_sol.verrouiller_ramassage(DUREE_VERROUILLAGE_JET)
	get_tree().current_scene.add_child(equipement_au_sol)
	equipement_au_sol.global_position = position_monde
	var equipement_retire: Dictionary = retirer_equipement_instance(identifiant_instance)
	if equipement_retire.is_empty():
		equipement_au_sol.queue_free()
		return false
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
