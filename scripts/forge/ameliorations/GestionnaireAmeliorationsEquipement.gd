extends RefCounted
class_name GestionnaireAmeliorationsEquipement

static func est_compatible(donnees_equipement: Dictionary, identifiant_amelioration: StringName) -> bool:
	var definition: LootItemEntry = _obtenir_definition(donnees_equipement)
	return definition != null and definition.ameliorations_compatibles.has(identifiant_amelioration) and definition.obtenir_amelioration_forge(identifiant_amelioration) != null

static func obtenir_ameliorations_installees(donnees_equipement: Dictionary) -> PackedStringArray:
	var composants: Dictionary = donnees_equipement.get("composants_installes", {})
	var ameliorations: Variant = composants.get(DonneesInstanceEquipement.CLE_AMELIORATIONS, PackedStringArray())
	if ameliorations is PackedStringArray:
		return ameliorations.duplicate()
	var resultat := PackedStringArray()
	if ameliorations is Array:
		for identifiant: Variant in ameliorations:
			resultat.append(StringName(identifiant))
	return resultat

static func installer_amelioration(inventaire: GestionnaireInventaire, identifiant_instance: StringName, identifiant_amelioration: StringName) -> bool:
	if inventaire == null or String(identifiant_amelioration).strip_edges() == "":
		return false
	var equipement: Dictionary = inventaire.obtenir_equipement_instance(identifiant_instance)
	if equipement.is_empty():
		return false
	var donnees: Dictionary = equipement.get("donnees", {}).duplicate(true)
	if not est_compatible(donnees, identifiant_amelioration):
		return false
	var ameliorations: PackedStringArray = obtenir_ameliorations_installees(donnees)
	if ameliorations.has(identifiant_amelioration):
		return false
	if inventaire.obtenir_quantite(identifiant_amelioration) < 1:
		return false
	ameliorations.append(identifiant_amelioration)
	var composants: Dictionary = donnees.get("composants_installes", {}).duplicate(true)
	composants[DonneesInstanceEquipement.CLE_AMELIORATIONS] = ameliorations
	donnees["composants_installes"] = composants
	if not inventaire.mettre_a_jour_equipement_instance(identifiant_instance, donnees):
		return false
	return inventaire.retirer_objet(identifiant_amelioration, 1) == 1

static func _obtenir_definition(donnees_equipement: Dictionary) -> LootItemEntry:
	var chemin_definition: String = String(donnees_equipement.get("chemin_definition", ""))
	return load(chemin_definition) as LootItemEntry if not chemin_definition.is_empty() else null
