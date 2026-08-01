extends Node
class_name GestionnaireCuisine

signal recette_changee(recette: RecetteCuisine)
signal cuisine_terminee(recette: RecetteCuisine)

@export var recettes_disponibles: Array[RecetteCuisine] = []

var joueur: Player
var inventaire: GestionnaireInventaire
var table_cuisine: TableCuisine
var recette_actuelle: RecetteCuisine

func _ready() -> void:
	if table_cuisine == null:
		table_cuisine = get_node_or_null("../TableCuisine") as TableCuisine
	if table_cuisine == null:
		push_error("TableCuisine introuvable pour GestionnaireCuisine.")
		return
	if not table_cuisine.contenu_change.is_connected(_quand_contenu_change):
		table_cuisine.contenu_change.connect(_quand_contenu_change)
	_quand_contenu_change()

func definir_joueur(nouveau_joueur: Player) -> void:
	joueur = nouveau_joueur
	inventaire = joueur.inventaire if joueur != null else null
	if joueur != null and inventaire == null:
		push_error("Le joueur present dans la cuisine ne possede pas de GestionnaireInventaire.")

func retirer_joueur() -> void:
	joueur = null
	inventaire = null

func deposer_ingredient(index_slot: int, objet: Dictionary) -> bool:
	if joueur == null or inventaire == null or table_cuisine == null or objet.is_empty():
		return false
	var identifiant: StringName = objet.get("identifiant", &"")
	if String(identifiant).is_empty() or not est_ingredient_autorise(identifiant):
		return false
	if inventaire.obtenir_quantite(identifiant) < 1:
		return false
	var objet_slot: Dictionary = objet.duplicate(true)
	objet_slot["quantite"] = 1
	if not table_cuisine.deposer_objet(index_slot, objet_slot):
		return false
	if inventaire.retirer_objet(identifiant, 1) == 1:
		return true
	table_cuisine.retirer_objet(index_slot)
	return false

func retirer_ingredient(index_slot: int) -> bool:
	if inventaire == null or table_cuisine == null:
		return false
	var objet: Dictionary = table_cuisine.retirer_objet(index_slot)
	if objet.is_empty():
		return false
	_ajouter_objet_inventaire(objet)
	return true

func rendre_tous_les_ingredients() -> void:
	if table_cuisine == null or inventaire == null:
		return
	var objets: Array[Dictionary] = table_cuisine.extraire_tous_les_objets()
	for objet: Dictionary in objets:
		_ajouter_objet_inventaire(objet)

func trouver_recette() -> RecetteCuisine:
	if table_cuisine == null:
		return null
	var quantites_presentes: Dictionary = table_cuisine.obtenir_contenu_total()
	for recette: RecetteCuisine in recettes_disponibles:
		if recette == null or not recette.est_valide():
			continue
		if recette.obtenir_quantites_ingredients() == quantites_presentes:
			return recette
	return null

func cuisiner() -> bool:
	if inventaire == null or table_cuisine == null:
		return false
	var recette: RecetteCuisine = trouver_recette()
	if recette == null or not recette.est_valide() or recette.resultat == null:
		return false
	var resultat: LootItemEntry = recette.resultat
	if String(resultat.item_id).is_empty():
		return false
	table_cuisine.extraire_tous_les_objets()
	inventaire.ajouter_objet(resultat.item_id, resultat.nom_affiche, recette.quantite_resultat, resultat.icone, Loot.TypeItem.CONSO, {"chemin_definition": resultat.resource_path})
	cuisine_terminee.emit(recette)
	return true

func est_ingredient_autorise(identifiant: StringName) -> bool:
	if String(identifiant).is_empty():
		return false
	for recette: RecetteCuisine in recettes_disponibles:
		if recette == null or not recette.est_valide():
			continue
		for ingredient: LootItemEntry in recette.ingredients:
			if ingredient != null and ingredient.item_id == identifiant:
				return true
	return false

func _ajouter_objet_inventaire(objet: Dictionary) -> void:
	var objet_rendu: Dictionary = objet.duplicate(true)
	objet_rendu["quantite"] = 1
	inventaire.ajouter_objet(objet_rendu.get("identifiant", &""), objet_rendu.get("nom", ""), 1, objet_rendu.get("icone", null), int(objet_rendu.get("type_item", -1)), objet_rendu.get("donnees", {}))

func _quand_contenu_change() -> void:
	var nouvelle_recette: RecetteCuisine = trouver_recette()
	if nouvelle_recette == recette_actuelle:
		return
	recette_actuelle = nouvelle_recette
	recette_changee.emit(recette_actuelle)
