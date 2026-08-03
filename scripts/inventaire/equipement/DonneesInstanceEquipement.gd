extends RefCounted
class_name DonneesInstanceEquipement

const CLE_AMELIORATIONS: StringName = &"ameliorations"
const CLE_IDENTIFIANT_INSTANCE: StringName = &"identifiant_instance"
const CLE_IDENTIFIANT_DEFINITION: StringName = &"identifiant_definition"
const CLE_CHEMIN_DEFINITION: StringName = &"chemin_definition"
const CLE_QUALITE: StringName = &"qualite"
const CLE_COMPOSANTS_INSTALLES: StringName = &"composants_installes"

static var compteur_instances: int = 0

static func creer(identifiant_definition: StringName, chemin_definition: String, qualite: StringName, composants_installes: Dictionary) -> Dictionary:
	compteur_instances += 1
	var composants: Dictionary = composants_installes.duplicate(true)
	composants[CLE_AMELIORATIONS] = PackedStringArray()
	return {
		CLE_IDENTIFIANT_INSTANCE: &"%s_%d_%d" % [identifiant_definition, Time.get_ticks_usec(), compteur_instances],
		CLE_IDENTIFIANT_DEFINITION: identifiant_definition,
		CLE_CHEMIN_DEFINITION: chemin_definition,
		CLE_QUALITE: qualite,
		CLE_COMPOSANTS_INSTALLES: composants
	}

static func est_valide_pour(donnees: Dictionary, definition: LootItemEntry) -> bool:
	if definition == null or String(definition.item_id).is_empty() or definition.resource_path.is_empty():
		return false
	var identifiant_instance: StringName = donnees.get(CLE_IDENTIFIANT_INSTANCE, &"")
	var identifiant_definition: StringName = donnees.get(CLE_IDENTIFIANT_DEFINITION, &"")
	var chemin_definition: String = String(donnees.get(CLE_CHEMIN_DEFINITION, ""))
	return not String(identifiant_instance).is_empty() and identifiant_definition == definition.item_id and chemin_definition == definition.resource_path

static func obtenir_composants_structurels(donnees: Dictionary) -> Dictionary:
	var composants: Dictionary = Dictionary(donnees.get(CLE_COMPOSANTS_INSTALLES, {})).duplicate(true)
	composants.erase(CLE_AMELIORATIONS)
	return composants
