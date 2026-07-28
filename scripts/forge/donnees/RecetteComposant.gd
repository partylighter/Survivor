extends Resource
class_name RecetteComposant

@export var identifiant: StringName = &""
@export var nom: String = ""
@export var ingredients: Array[IngredientRecette] = []
@export var etapes: Array[EtapeFabrication] = []
@export var resultat: LootItemEntry
@export_range(1, 999, 1) var quantite_resultat: int = 1

func obtenir_erreurs() -> Array[String]:
	var erreurs: Array[String] = []
	if String(identifiant).strip_edges() == "":
		erreurs.append("La recette n'a pas d'identifiant.")
	if nom.strip_edges() == "":
		erreurs.append("La recette n'a pas de nom.")
	if ingredients.is_empty():
		erreurs.append("La recette n'a aucun ingredient.")
	var identifiants_vus: Dictionary = {}
	for index: int in ingredients.size():
		var ingredient: IngredientRecette = ingredients[index]
		if ingredient == null:
			erreurs.append("L'ingredient %d est manquant." % (index + 1))
			continue
		if ingredient.objet == null:
			erreurs.append("L'objet de l'ingredient %d est manquant." % (index + 1))
			continue
		if String(ingredient.objet.item_id).strip_edges() == "":
			erreurs.append("L'ingredient %d n'a pas d'identifiant." % (index + 1))
		elif identifiants_vus.has(ingredient.objet.item_id):
			erreurs.append("L'ingredient %s est present plusieurs fois." % String(ingredient.objet.item_id))
		else:
			identifiants_vus[ingredient.objet.item_id] = true
		if ingredient.quantite < 1:
			erreurs.append("La quantite de l'ingredient %d est invalide." % (index + 1))
	if resultat == null:
		erreurs.append("Le resultat de la recette est manquant.")
	elif String(resultat.item_id).strip_edges() == "":
		erreurs.append("Le resultat de la recette n'a pas d'identifiant.")
	if quantite_resultat < 1:
		erreurs.append("La quantite du resultat est invalide.")
	if not _parcours_est_valide():
		erreurs.append("Les etapes doivent etre CHAUFFE puis MARTELAGE, ou FONTE puis MOULAGE.")
	return erreurs

func est_valide() -> bool:
	return obtenir_erreurs().is_empty()

func obtenir_materiaux_manquants(inventaire: GestionnaireInventaire) -> Dictionary:
	var materiaux_manquants: Dictionary = {}
	for ingredient: IngredientRecette in ingredients:
		if ingredient == null or ingredient.objet == null or ingredient.quantite < 1:
			continue
		var quantite_possedee: int = inventaire.obtenir_quantite(ingredient.objet.item_id) if inventaire != null else 0
		if quantite_possedee < ingredient.quantite:
			materiaux_manquants[ingredient.objet.item_id] = ingredient.quantite - quantite_possedee
	return materiaux_manquants

func peut_fabriquer(inventaire: GestionnaireInventaire) -> bool:
	return est_valide() and obtenir_materiaux_manquants(inventaire).is_empty()

func _parcours_est_valide() -> bool:
	if etapes.size() != 2 or etapes[0] == null or etapes[1] == null:
		return false
	var premiere_etape: EtapeFabrication.TypeEtape = etapes[0].type_etape
	var deuxieme_etape: EtapeFabrication.TypeEtape = etapes[1].type_etape
	return (
		premiere_etape == EtapeFabrication.TypeEtape.CHAUFFE
		and deuxieme_etape == EtapeFabrication.TypeEtape.MARTELAGE
	) or (
		premiere_etape == EtapeFabrication.TypeEtape.FONTE
		and deuxieme_etape == EtapeFabrication.TypeEtape.MOULAGE
	)
