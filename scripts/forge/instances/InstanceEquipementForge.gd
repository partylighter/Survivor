extends RefCounted
class_name InstanceEquipementForge

static func creer(identifiant_definition: StringName, chemin_definition: String, qualite: StringName, composants_installes: Dictionary) -> Dictionary:
	return DonneesInstanceEquipement.creer(identifiant_definition, chemin_definition, qualite, composants_installes)
