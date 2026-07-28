extends RefCounted
class_name FabricationActive

var recette: RecetteComposant
var difficulte: DonneesCommandeForge.Difficulte = DonneesCommandeForge.Difficulte.FACILE
var materiaux_selectionnes: Dictionary = {}
var index_etape_actuelle: int = 0
var resultats_etapes: Dictionary = {}
var qualite_finale: StringName = &""
var finalisee: bool = false

func initialiser(nouvelle_recette: RecetteComposant, nouvelle_difficulte: DonneesCommandeForge.Difficulte, nouvelle_selection: Dictionary) -> bool:
	if nouvelle_recette == null or not nouvelle_recette.est_valide() or nouvelle_selection.is_empty():
		return false
	if nouvelle_selection.size() != nouvelle_recette.ingredients.size():
		return false
	for ingredient: IngredientRecette in nouvelle_recette.ingredients:
		if ingredient == null or ingredient.objet == null or int(nouvelle_selection.get(ingredient.objet.item_id, 0)) != ingredient.quantite:
			return false
	recette = nouvelle_recette
	difficulte = nouvelle_difficulte
	materiaux_selectionnes = nouvelle_selection.duplicate(true)
	index_etape_actuelle = 0
	resultats_etapes.clear()
	qualite_finale = &""
	finalisee = false
	return true

func obtenir_etape_actuelle() -> EtapeFabrication:
	if recette == null or index_etape_actuelle < 0 or index_etape_actuelle >= recette.etapes.size():
		return null
	return recette.etapes[index_etape_actuelle]

func avancer_etape() -> void:
	if not est_terminee():
		index_etape_actuelle += 1

func enregistrer_resultat_etape(type_etape: EtapeFabrication.TypeEtape, resultat: StringName) -> void:
	resultats_etapes[type_etape] = resultat

func est_terminee() -> bool:
	return recette == null or index_etape_actuelle >= recette.etapes.size()

func calculer_qualite_finale() -> StringName:
	if not est_terminee() or recette == null or resultats_etapes.size() < recette.etapes.size():
		return &""
	var tous_parfaits: bool = true
	for etape: EtapeFabrication in recette.etapes:
		if etape == null:
			return &""
		var resultat: StringName = resultats_etapes.get(etape.type_etape, &"")
		if resultat == &"echec":
			qualite_finale = &"mauvaise"
			return qualite_finale
		if resultat != &"parfait":
			tous_parfaits = false
	qualite_finale = &"parfaite" if tous_parfaits else &"correcte"
	return qualite_finale

func est_prete_assemblage() -> bool:
	return est_terminee() and not finalisee and calculer_qualite_finale() != &""
