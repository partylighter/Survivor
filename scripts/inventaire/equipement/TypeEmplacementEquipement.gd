extends RefCounted
class_name TypeEmplacementEquipement

enum Type {
	TETE,
	COU,
	CORPS,
	BRAS,
	MAINS,
	JAMBES,
	PIEDS,
	DOIGT,
	OUTIL
}

static func obtenir_nom(type_emplacement: Type) -> String:
	match type_emplacement:
		Type.TETE:
			return "Tête"
		Type.COU:
			return "Cou"
		Type.CORPS:
			return "Corps"
		Type.BRAS:
			return "Bras"
		Type.MAINS:
			return "Mains"
		Type.JAMBES:
			return "Jambes"
		Type.PIEDS:
			return "Pieds"
		Type.DOIGT:
			return "Doigt"
		Type.OUTIL:
			return "Outil"
	return "Inconnu"
