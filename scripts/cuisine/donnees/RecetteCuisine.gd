extends Resource
class_name RecetteCuisine

@export var identifiant: StringName = &""
@export var nom: String = ""
@export var ingredients: Array[LootItemEntry] = []
@export var resultat: LootItemEntry
@export_range(1, 99, 1) var quantite_resultat: int = 1

func est_valide() -> bool:
	return obtenir_erreurs().is_empty()

func obtenir_erreurs() -> Array[String]:
	var erreurs: Array[String] = []
	if String(identifiant).is_empty():
		erreurs.append("L'identifiant de la recette est vide.")
	if nom.strip_edges().is_empty():
		erreurs.append("Le nom de la recette est vide.")
	if ingredients.is_empty():
		erreurs.append("La recette ne contient aucun ingredient.")
	if ingredients.size() > TableCuisine.NOMBRE_SLOTS:
		erreurs.append("La recette contient plus de trois ingredients.")
	for index: int in ingredients.size():
		var ingredient: LootItemEntry = ingredients[index]
		if ingredient == null:
			erreurs.append("L'ingredient %d est manquant." % (index + 1))
		elif String(ingredient.item_id).is_empty():
			erreurs.append("L'ingredient %d possede un item_id vide." % (index + 1))
	if resultat == null:
		erreurs.append("Le resultat de la recette est manquant.")
	elif String(resultat.item_id).is_empty():
		erreurs.append("Le resultat possede un item_id vide.")
	if quantite_resultat < 1:
		erreurs.append("La quantite du resultat doit etre superieure ou egale a 1.")
	return erreurs

func obtenir_quantites_ingredients() -> Dictionary:
	var quantites: Dictionary = {}
	for ingredient: LootItemEntry in ingredients:
		if ingredient == null or String(ingredient.item_id).is_empty():
			continue
		quantites[ingredient.item_id] = int(quantites.get(ingredient.item_id, 0)) + 1
	return quantites
