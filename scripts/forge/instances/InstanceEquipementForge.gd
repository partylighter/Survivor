extends RefCounted
class_name InstanceEquipementForge

static var compteur_instances: int = 0

static func creer(identifiant_definition: StringName, chemin_definition: String, qualite: StringName, composants_installes: Dictionary) -> Dictionary:
	compteur_instances += 1
	var composants: Dictionary = composants_installes.duplicate(true)
	composants[GestionnaireAmeliorationsEquipement.CLE_AMELIORATIONS] = PackedStringArray()
	return {
		"identifiant_instance": &"%s_%d_%d" % [identifiant_definition, Time.get_ticks_usec(), compteur_instances],
		"identifiant_definition": identifiant_definition,
		"chemin_definition": chemin_definition,
		"qualite": qualite,
		"composants_installes": composants
	}
