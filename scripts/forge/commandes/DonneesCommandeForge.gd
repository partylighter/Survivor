extends Resource
class_name DonneesCommandeForge

enum Difficulte {
	FACILE,
	NORMALE,
	DIFFICILE
}

@export var identifiant: StringName = &""
@export var nom: String = ""
@export var objet_demande: LootItemEntry
@export var recette: RecetteComposant
@export var recettes_composants: Array[RecetteComposant] = []
@export var recette_assemblage: RecetteEquipement
@export_range(1, 999, 1) var quantite_demandee: int = 1
@export var difficulte: Difficulte = Difficulte.FACILE
@export_range(1, 999999, 1) var prix: int = 1

func obtenir_erreurs() -> Array[String]:
	var erreurs: Array[String] = []
	if String(identifiant).strip_edges() == "":
		erreurs.append("La commande n'a pas d'identifiant.")
	if nom.strip_edges() == "":
		erreurs.append("La commande n'a pas de nom.")
	if objet_demande == null:
		erreurs.append("L'objet demande est manquant.")
	elif String(objet_demande.item_id).strip_edges() == "":
		erreurs.append("L'objet demande n'a pas d'identifiant.")
	if recette_assemblage != null:
		if not recette_assemblage.est_valide():
			erreurs.append("La recette d'assemblage de la commande est invalide.")
		elif objet_demande != null and recette_assemblage.resultat.item_id != objet_demande.item_id:
			erreurs.append("Le resultat de l'assemblage ne correspond pas a l'objet demande.")
		if recettes_composants.is_empty():
			erreurs.append("La commande n'a aucune recette de composant.")
		else:
			var composants_fabricables: Dictionary = {}
			for recette_composant: RecetteComposant in recettes_composants:
				if recette_composant == null or not recette_composant.est_valide():
					erreurs.append("Une recette de composant de la commande est invalide.")
				else:
					composants_fabricables[recette_composant.resultat.item_id] = true
			for composant: LootItemEntry in recette_assemblage.obtenir_composants_uniques():
				if composant != null and not composants_fabricables.has(composant.item_id):
					erreurs.append("Aucune recette ne permet de fabriquer %s." % composant.nom_affiche)
	elif recette == null:
		erreurs.append("La recette de la commande est manquante.")
	elif not recette.est_valide():
		erreurs.append("La recette de la commande est invalide.")
	elif objet_demande != null and recette.resultat.item_id != objet_demande.item_id:
		erreurs.append("Le resultat de la recette ne correspond pas a l'objet demande.")
	if quantite_demandee < 1:
		erreurs.append("La quantite demandee est invalide.")
	if int(difficulte) < Difficulte.FACILE or int(difficulte) > Difficulte.DIFFICILE:
		erreurs.append("La difficulte est invalide.")
	if prix < 1:
		erreurs.append("Le prix de la commande est invalide.")
	return erreurs

func est_valide() -> bool:
	return obtenir_erreurs().is_empty()
