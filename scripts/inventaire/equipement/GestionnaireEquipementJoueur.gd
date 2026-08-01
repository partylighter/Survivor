extends Node
class_name GestionnaireEquipementJoueur

signal equipement_change
signal outil_actif_change(index_actif: int)

enum Emplacement {
	TETE,
	COU,
	CORPS,
	BRAS,
	MAINS,
	JAMBES,
	PIEDS,
	ANNEAU_1,
	ANNEAU_2,
	OUTIL_1,
	OUTIL_2
}

@export_node_path("GestionnaireInventaire") var chemin_inventaire: NodePath = NodePath("../GestionnaireInventaire")
@export_node_path("GestionnaireArme") var chemin_gestionnaire_arme: NodePath = NodePath("../GestionnaireArme")

@onready var inventaire: GestionnaireInventaire = get_node_or_null(chemin_inventaire) as GestionnaireInventaire
@onready var gestionnaire_arme: GestionnaireArme = get_node_or_null(chemin_gestionnaire_arme) as GestionnaireArme

var equipements: Dictionary = {}
var outils: Array[Dictionary] = [{}, {}]
var index_outil_actif: int = -1

func obtenir_type_emplacement(emplacement: Emplacement) -> TypeEmplacementEquipement.Type:
	match emplacement:
		Emplacement.TETE:
			return TypeEmplacementEquipement.Type.TETE
		Emplacement.COU:
			return TypeEmplacementEquipement.Type.COU
		Emplacement.CORPS:
			return TypeEmplacementEquipement.Type.CORPS
		Emplacement.BRAS:
			return TypeEmplacementEquipement.Type.BRAS
		Emplacement.MAINS:
			return TypeEmplacementEquipement.Type.MAINS
		Emplacement.JAMBES:
			return TypeEmplacementEquipement.Type.JAMBES
		Emplacement.PIEDS:
			return TypeEmplacementEquipement.Type.PIEDS
		Emplacement.ANNEAU_1, Emplacement.ANNEAU_2:
			return TypeEmplacementEquipement.Type.DOIGT
		Emplacement.OUTIL_1, Emplacement.OUTIL_2:
			return TypeEmplacementEquipement.Type.OUTIL
	return TypeEmplacementEquipement.Type.OUTIL

func obtenir_nom_emplacement(emplacement: Emplacement) -> String:
	match emplacement:
		Emplacement.ANNEAU_1:
			return "Anneau 1"
		Emplacement.ANNEAU_2:
			return "Anneau 2"
		Emplacement.OUTIL_1:
			return "Outil 1"
		Emplacement.OUTIL_2:
			return "Outil 2"
	return TypeEmplacementEquipement.obtenir_nom(obtenir_type_emplacement(emplacement))

func obtenir_objet_equipe(emplacement: Emplacement) -> Dictionary:
	if emplacement == Emplacement.OUTIL_1:
		return outils[0].duplicate(true)
	if emplacement == Emplacement.OUTIL_2:
		return outils[1].duplicate(true)
	return Dictionary(equipements.get(emplacement, {})).duplicate(true)

func obtenir_outil_actif() -> Dictionary:
	if index_outil_actif < 0 or index_outil_actif >= outils.size():
		return {}
	return outils[index_outil_actif].duplicate(true)

func obtenir_outil_secondaire() -> Dictionary:
	if index_outil_actif < 0:
		return {}
	return outils[1 - index_outil_actif].duplicate(true)

func peut_equiper(objet: Dictionary, emplacement: Emplacement) -> bool:
	var donnees_equipement: DonneesEquipement = _obtenir_donnees_equipement(objet)
	return donnees_equipement != null and donnees_equipement.type_emplacement == obtenir_type_emplacement(emplacement)

func trouver_emplacement_pour(objet: Dictionary) -> int:
	for index: int in Emplacement.size():
		var emplacement: Emplacement = index as Emplacement
		if peut_equiper(objet, emplacement) and obtenir_objet_equipe(emplacement).is_empty():
			return index
	for index: int in Emplacement.size():
		var emplacement: Emplacement = index as Emplacement
		if peut_equiper(objet, emplacement):
			return index
	return -1

func equiper_depuis_inventaire(objet: Dictionary, emplacement: Emplacement) -> bool:
	if inventaire == null or not peut_equiper(objet, emplacement):
		return false
	var objet_retire: Dictionary = _retirer_exactement(objet)
	if objet_retire.is_empty():
		return false
	var reussi: bool = _equiper_outil(objet_retire, emplacement) if obtenir_type_emplacement(emplacement) == TypeEmplacementEquipement.Type.OUTIL else _equiper_corps(objet_retire, emplacement)
	if not reussi:
		inventaire.ajouter_depuis_payload(objet_retire)
	return reussi

func desequiper(emplacement: Emplacement) -> bool:
	if inventaire == null:
		return false
	if obtenir_type_emplacement(emplacement) == TypeEmplacementEquipement.Type.OUTIL:
		return _desequiper_outil(0 if emplacement == Emplacement.OUTIL_1 else 1)
	var objet: Dictionary = Dictionary(equipements.get(emplacement, {}))
	if objet.is_empty():
		return false
	if not inventaire.ajouter_depuis_payload(objet):
		return false
	equipements.erase(emplacement)
	equipement_change.emit()
	return true

func permuter_outil_actif() -> void:
	if index_outil_actif < 0:
		return
	var nouvel_index: int = 1 - index_outil_actif
	if outils[nouvel_index].is_empty() or gestionnaire_arme == null:
		return
	var ancien_index: int = index_outil_actif
	var ancienne_arme: Dictionary = gestionnaire_arme.extraire_equipement_principal_sans_inventaire()
	if not outils[ancien_index].is_empty() and ancienne_arme.is_empty():
		return
	if not gestionnaire_arme.equiper_equipement_stocke(outils[nouvel_index]):
		if not ancienne_arme.is_empty():
			gestionnaire_arme.equiper_equipement_stocke(ancienne_arme)
		return
	index_outil_actif = nouvel_index
	outil_actif_change.emit(index_outil_actif)
	equipement_change.emit()

func _equiper_corps(objet: Dictionary, emplacement: Emplacement) -> bool:
	var ancien: Dictionary = Dictionary(equipements.get(emplacement, {}))
	if not ancien.is_empty() and not inventaire.ajouter_depuis_payload(ancien):
		return false
	equipements[emplacement] = objet
	equipement_change.emit()
	return true

func _equiper_outil(objet: Dictionary, emplacement: Emplacement) -> bool:
	if gestionnaire_arme == null:
		return false
	var index: int = 0 if emplacement == Emplacement.OUTIL_1 else 1
	var ancien: Dictionary = outils[index].duplicate(true)
	var doit_activer: bool = index_outil_actif == index or index_outil_actif < 0
	var ancienne_arme: Dictionary = {}
	if doit_activer and index_outil_actif == index:
		ancienne_arme = gestionnaire_arme.extraire_equipement_principal_sans_inventaire()
		if not ancien.is_empty() and ancienne_arme.is_empty():
			return false
	if doit_activer and not gestionnaire_arme.equiper_equipement_stocke(objet):
		if not ancienne_arme.is_empty():
			gestionnaire_arme.equiper_equipement_stocke(ancienne_arme)
		return false
	if not ancien.is_empty() and not inventaire.ajouter_depuis_payload(ancien):
		if doit_activer:
			gestionnaire_arme.extraire_equipement_principal_sans_inventaire()
			if not ancienne_arme.is_empty():
				gestionnaire_arme.equiper_equipement_stocke(ancienne_arme)
		return false
	outils[index] = objet
	if index_outil_actif < 0:
		index_outil_actif = index
	outil_actif_change.emit(index_outil_actif)
	equipement_change.emit()
	return true

func _desequiper_outil(index: int) -> bool:
	var objet: Dictionary = outils[index]
	if objet.is_empty():
		return false
	var arme_extraite: Dictionary = {}
	if index == index_outil_actif:
		if gestionnaire_arme == null:
			return false
		arme_extraite = gestionnaire_arme.extraire_equipement_principal_sans_inventaire()
		if arme_extraite.is_empty():
			return false
	if not inventaire.ajouter_depuis_payload(objet):
		if not arme_extraite.is_empty():
			gestionnaire_arme.equiper_equipement_stocke(arme_extraite)
		return false
	outils[index] = {}
	if index == index_outil_actif:
		var autre_index: int = 1 - index
		index_outil_actif = autre_index if not outils[autre_index].is_empty() else -1
		if index_outil_actif >= 0 and not gestionnaire_arme.equiper_equipement_stocke(outils[index_outil_actif]):
			index_outil_actif = -1
	outil_actif_change.emit(index_outil_actif)
	equipement_change.emit()
	return true

func _retirer_exactement(objet: Dictionary) -> Dictionary:
	var donnees: Dictionary = objet.get("donnees", {})
	var identifiant_instance: StringName = donnees.get("identifiant_instance", &"")
	if String(identifiant_instance) != "":
		return inventaire.retirer_equipement_instance(identifiant_instance)
	var identifiant: StringName = objet.get("identifiant", &"")
	if inventaire.retirer_objet(identifiant, 1) != 1:
		return {}
	var objet_unitaire: Dictionary = objet.duplicate(true)
	objet_unitaire["quantite"] = 1
	return objet_unitaire

func _obtenir_donnees_equipement(objet: Dictionary) -> DonneesEquipement:
	var donnees: Dictionary = objet.get("donnees", {})
	var chemin_definition: String = String(donnees.get("chemin_definition", ""))
	if chemin_definition.is_empty():
		return null
	var definition: LootItemEntry = load(chemin_definition) as LootItemEntry
	return definition.donnees_equipement if definition != null else null
