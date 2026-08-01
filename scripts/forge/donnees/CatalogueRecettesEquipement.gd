extends Resource
class_name CatalogueRecettesEquipement

@export var recettes: Array[RecetteEquipement] = []

func obtenir_definition(identifiant: StringName) -> LootItemEntry:
	for recette: RecetteEquipement in recettes:
		if recette == null:
			continue
		if recette.resultat != null and recette.resultat.item_id == identifiant:
			return recette.resultat
		for composant: LootItemEntry in recette.obtenir_composants_uniques():
			if composant.item_id == identifiant:
				return composant
	return null
