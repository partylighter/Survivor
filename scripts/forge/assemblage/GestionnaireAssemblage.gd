extends Node
class_name GestionnaireAssemblage

signal assemblage_termine(resultat: Dictionary)

var derniere_erreur: String = ""

func assembler_objet(recette: RecetteEquipement, table: TableForge, inventaire: GestionnaireInventaire, gestionnaire_recettes: GestionnaireRecettesAssemblage) -> Dictionary:
	derniere_erreur = ""
	if recette == null or not recette.est_valide():
		derniere_erreur = "La recette d'assemblage est invalide."
		return {}
	if table == null or inventaire == null or gestionnaire_recettes == null:
		derniere_erreur = "La table, l'inventaire ou les recettes sont introuvables."
		return {}
	if gestionnaire_recettes.trouver_recette(table) != recette:
		derniere_erreur = "Le motif de la grille ne correspond plus a la recette."
		return {}
	var quantites_requises: Dictionary = recette.obtenir_quantites_composants()
	var qualite: StringName = _calculer_qualite_composants(table)
	var donnees_instance: Dictionary = InstanceEquipementForge.creer(recette.resultat.item_id, recette.resultat.resource_path, qualite, quantites_requises)
	table.consommer_un_objet_par_slot_occupe()
	inventaire.ajouter_objet(
		recette.resultat.item_id,
		recette.resultat.nom_affiche,
		recette.quantite_resultat,
		recette.resultat.icone,
		Loot.TypeItem.EQUIPEMENT,
		donnees_instance
	)
	var resultat: Dictionary = {
		"identifiant": recette.resultat.item_id,
		"nom": recette.resultat.nom_affiche,
		"icone": recette.resultat.icone,
		"quantite": recette.quantite_resultat,
		"qualite": qualite,
		"identifiant_instance": donnees_instance["identifiant_instance"]
	}
	assemblage_termine.emit(resultat)
	return resultat

func _calculer_qualite_composants(table: TableForge) -> StringName:
	var tous_parfaits: bool = true
	for index: int in TableForge.NOMBRE_SLOTS:
		var objet: Dictionary = table.obtenir_objet_du_slot(index)
		if objet.is_empty():
			continue
		var donnees: Dictionary = objet.get("donnees", {})
		var qualite: StringName = donnees.get("qualite", &"correcte")
		if qualite == &"mauvaise":
			return &"mauvaise"
		if qualite != &"parfaite":
			tous_parfaits = false
	return &"parfaite" if tous_parfaits else &"correcte"
