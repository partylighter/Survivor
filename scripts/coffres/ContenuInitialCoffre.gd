extends Resource
class_name ContenuInitialCoffre

@export var objet: LootItemEntry
@export_range(1, 999, 1) var quantite: int = 1
@export_enum("CONSO", "UPGRADE", "ARME", "MATERIAU", "COMPOSANT", "EQUIPEMENT") var type_item: int = Loot.TypeItem.MATERIAU
@export_enum("C", "B", "A", "S") var type_loot: int = Loot.TypeLoot.C

func obtenir_objet() -> Dictionary:
	if objet == null or String(objet.item_id) == "":
		return {}
	var type_effectif: int = Loot.TypeItem.EQUIPEMENT if est_equipement() else type_item
	var donnees: Dictionary = {}
	if est_equipement():
		donnees = DonneesInstanceEquipement.creer(objet.item_id, objet.resource_path, &"correcte", {})
	return {
		"identifiant": objet.item_id,
		"nom": objet.nom_affiche,
		"icone": objet.icone,
		"quantite": 1 if est_equipement() else quantite,
		"type_item": type_effectif,
		"type_loot": type_loot,
		"donnees": donnees
	}

func est_equipement() -> bool:
	return objet != null and objet.type_item == Loot.TypeItem.EQUIPEMENT and objet.donnees_equipement != null
