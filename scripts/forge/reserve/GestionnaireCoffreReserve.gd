extends Node
class_name GestionnaireCoffreReserve

signal stock_change

@export var objets_disponibles: Array[LootItemEntry] = []
@export var quantites_initiales: PackedInt32Array = PackedInt32Array()

var stock_par_identifiant: Dictionary = {}

func _ready() -> void:
	if objets_disponibles.size() != quantites_initiales.size():
		push_error("Le coffre de reserve doit avoir une quantite initiale pour chaque objet.")
	for index: int in objets_disponibles.size():
		var objet: LootItemEntry = objets_disponibles[index]
		if objet == null or String(objet.item_id) == "":
			push_error("Le coffre de reserve contient un objet invalide a l'index %d." % index)
			continue
		if stock_par_identifiant.has(objet.item_id):
			push_error("L'objet %s est present plusieurs fois dans le coffre de reserve." % String(objet.item_id))
			continue
		var quantite: int = quantites_initiales[index] if index < quantites_initiales.size() else 0
		stock_par_identifiant[objet.item_id] = maxi(quantite, 0)

func obtenir_stock(identifiant: StringName) -> int:
	return int(stock_par_identifiant.get(identifiant, 0))

func obtenir_objet(identifiant: StringName) -> LootItemEntry:
	for objet: LootItemEntry in objets_disponibles:
		if objet != null and objet.item_id == identifiant:
			return objet
	return null

func recuperer_ingredients_manquants(recette: RecetteComposant, inventaire: GestionnaireInventaire) -> Dictionary:
	var resultat: Dictionary = {"quantite_totale": 0, "stock_insuffisant": []}
	if recette == null or not recette.est_valide() or inventaire == null:
		return resultat
	for ingredient: IngredientRecette in recette.ingredients:
		if ingredient == null or ingredient.objet == null:
			continue
		var identifiant: StringName = ingredient.objet.item_id
		var quantite_manquante: int = maxi(ingredient.quantite - inventaire.obtenir_quantite(identifiant), 0)
		if quantite_manquante <= 0:
			continue
		var objet: LootItemEntry = obtenir_objet(identifiant)
		var quantite_prise: int = mini(quantite_manquante, obtenir_stock(identifiant))
		if objet != null and quantite_prise > 0:
			inventaire.ajouter_objet(objet.item_id, objet.nom_affiche, quantite_prise, objet.icone, Loot.TypeItem.MATERIAU)
			stock_par_identifiant[identifiant] = obtenir_stock(identifiant) - quantite_prise
			resultat["quantite_totale"] = int(resultat["quantite_totale"]) + quantite_prise
		if quantite_prise < quantite_manquante:
			(resultat["stock_insuffisant"] as Array).append(ingredient.objet.nom_affiche)
	if int(resultat["quantite_totale"]) > 0:
		stock_change.emit()
	return resultat
