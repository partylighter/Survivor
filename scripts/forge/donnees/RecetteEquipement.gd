extends Resource
class_name RecetteEquipement

const NOMBRE_OBJETS_ASSEMBLAGE_MAXIMUM: int = 9

@export var identifiant: StringName = &""
@export var nom: String = ""
@export_range(1, 3, 1) var largeur_motif: int = 1
@export_range(1, 3, 1) var hauteur_motif: int = 1
@export var motif: Array[LootItemEntry] = []
@export var autoriser_decalage: bool = true
@export var autoriser_miroir: bool = false
@export var resultat: LootItemEntry
@export_range(1, 999, 1) var quantite_resultat: int = 1

func obtenir_erreurs() -> Array[String]:
	var erreurs: Array[String] = []
	if String(identifiant).strip_edges() == "":
		erreurs.append("La recette d'equipement n'a pas d'identifiant.")
	if nom.strip_edges() == "":
		erreurs.append("La recette d'equipement n'a pas de nom.")
	if largeur_motif < 1 or largeur_motif > 3 or hauteur_motif < 1 or hauteur_motif > 3:
		erreurs.append("Les dimensions du motif doivent etre comprises entre 1 et 3.")
	if motif.size() != largeur_motif * hauteur_motif:
		erreurs.append("Le motif doit contenir exactement %d cases." % (largeur_motif * hauteur_motif))
	var quantite_totale: int = 0
	for composant: LootItemEntry in motif:
		if composant != null:
			quantite_totale += 1
	if quantite_totale == 0:
		erreurs.append("Le motif ne contient aucun composant.")
	if quantite_totale > NOMBRE_OBJETS_ASSEMBLAGE_MAXIMUM:
		erreurs.append("La recette demande %d composants, mais la table ne contient que %d emplacements." % [quantite_totale, NOMBRE_OBJETS_ASSEMBLAGE_MAXIMUM])
	if resultat == null or String(resultat.item_id).strip_edges() == "":
		erreurs.append("Le resultat de la recette d'equipement est invalide.")
	elif resultat.type_item != Loot.TypeItem.EQUIPEMENT:
		erreurs.append("Le resultat de la recette doit etre un equipement.")
	if quantite_resultat != 1:
		erreurs.append("Une recette d'equipement doit produire exactement une instance.")
	return erreurs

func est_valide() -> bool:
	return obtenir_erreurs().is_empty()

func obtenir_quantites_composants() -> Dictionary:
	var quantites: Dictionary = {}
	for composant: LootItemEntry in motif:
		if composant != null:
			quantites[composant.item_id] = int(quantites.get(composant.item_id, 0)) + 1
	return quantites

func obtenir_composants_uniques() -> Array[LootItemEntry]:
	var composants: Array[LootItemEntry] = []
	var identifiants_vus: Dictionary = {}
	for composant: LootItemEntry in motif:
		if composant != null and not identifiants_vus.has(composant.item_id):
			identifiants_vus[composant.item_id] = true
			composants.append(composant)
	return composants
