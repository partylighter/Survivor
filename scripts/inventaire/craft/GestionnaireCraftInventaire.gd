extends Node
class_name GestionnaireCraftInventaire

signal table_changee
signal recette_changee(recette: RecetteEquipement)
signal cible_desassemblage_changee(objet: Dictionary)
signal assemblage_reussi(resultat: Dictionary)
signal desassemblage_reussi(objet: Dictionary)

@export_node_path("GestionnaireInventaire") var chemin_inventaire: NodePath = NodePath("../GestionnaireInventaire")
@export_node_path("GestionnaireEquipementJoueur") var chemin_gestionnaire_equipement: NodePath = NodePath("../GestionnaireEquipementJoueur")
@export var catalogue_recettes: CatalogueRecettesEquipement

@onready var inventaire: GestionnaireInventaire = get_node_or_null(chemin_inventaire) as GestionnaireInventaire
@onready var gestionnaire_equipement: GestionnaireEquipementJoueur = get_node_or_null(chemin_gestionnaire_equipement) as GestionnaireEquipementJoueur

var table: TableCraftInventaire = TableCraftInventaire.new()
var recette_detectee: RecetteEquipement
var cible_desassemblage: Dictionary = {}
var derniere_erreur: String = ""

func deposer_objet(index_slot: int, objet: Dictionary) -> bool:
	derniere_erreur = ""
	if inventaire == null or int(objet.get("type_item", -1)) != Loot.TypeItem.COMPOSANT:
		derniere_erreur = "Seuls les composants peuvent etre assembles."
		return false
	if not table.deposer(index_slot, objet):
		derniere_erreur = "Cet emplacement n'est pas disponible."
		return false
	var identifiant: StringName = objet.get("identifiant", &"")
	if inventaire.retirer_objet(identifiant, 1) != 1:
		table.retirer(index_slot)
		derniere_erreur = "Le composant n'est plus disponible dans l'inventaire."
		return false
	_actualiser_recette()
	return true

func deposer_dans_premier_slot(objet: Dictionary) -> bool:
	return deposer_objet(table.trouver_premier_slot_vide(), objet)

func retirer_objet(index_slot: int) -> bool:
	derniere_erreur = ""
	var objet: Dictionary = table.obtenir(index_slot)
	if objet.is_empty():
		return false
	if inventaire == null or not inventaire.ajouter_depuis_payload(objet):
		derniere_erreur = "Impossible de rendre le composant a l'inventaire."
		return false
	table.retirer(index_slot)
	_actualiser_recette()
	return true

func annuler_craft() -> bool:
	derniere_erreur = ""
	var reussi: bool = true
	for index: int in TableCraftInventaire.NOMBRE_SLOTS:
		if not table.obtenir(index).is_empty() and not retirer_objet(index):
			reussi = false
	annuler_desassemblage()
	return reussi

func assembler() -> Dictionary:
	derniere_erreur = ""
	if inventaire == null:
		derniere_erreur = "L'inventaire est introuvable."
		return {}
	_actualiser_recette(false)
	if recette_detectee == null:
		derniere_erreur = "Aucune recette ne correspond exactement aux trois emplacements."
		return {}
	var resultat: LootItemEntry = recette_detectee.resultat
	var instances_ajoutees: Array[StringName] = []
	for index: int in recette_detectee.quantite_resultat:
		var donnees_instance: Dictionary = DonneesInstanceEquipement.creer(resultat.item_id, resultat.resource_path, &"correcte", table.obtenir_quantites())
		var payload: Dictionary = {
			"identifiant": resultat.item_id,
			"nom": resultat.nom_affiche,
			"icone": resultat.icone,
			"quantite": 1,
			"type_item": Loot.TypeItem.EQUIPEMENT,
			"donnees": donnees_instance
		}
		if not inventaire.ajouter_depuis_payload(payload):
			for identifiant_instance: StringName in instances_ajoutees:
				inventaire.retirer_equipement_instance(identifiant_instance)
			derniere_erreur = "Impossible d'ajouter le resultat. Les composants ont ete conserves."
			return {}
		instances_ajoutees.append(donnees_instance.get(DonneesInstanceEquipement.CLE_IDENTIFIANT_INSTANCE, &""))
	var premier_resultat: Dictionary = inventaire.obtenir_equipement_instance(instances_ajoutees[0])
	table.vider()
	_actualiser_recette()
	assemblage_reussi.emit(premier_resultat)
	return premier_resultat

func selectionner_pour_desassemblage(objet: Dictionary) -> bool:
	derniere_erreur = ""
	if not peut_desassembler(objet):
		return false
	cible_desassemblage = objet.duplicate(true)
	cible_desassemblage_changee.emit(cible_desassemblage.duplicate(true))
	return true

func peut_desassembler(objet: Dictionary) -> bool:
	if int(objet.get("type_item", -1)) != Loot.TypeItem.EQUIPEMENT:
		derniere_erreur = "Seul un equipement forge peut etre desassemble."
		return false
	var donnees: Dictionary = objet.get("donnees", {})
	var identifiant_instance: StringName = donnees.get(DonneesInstanceEquipement.CLE_IDENTIFIANT_INSTANCE, &"")
	if String(identifiant_instance) == "" or DonneesInstanceEquipement.obtenir_composants_structurels(donnees).is_empty():
		derniere_erreur = "Cet equipement ne contient aucun composant installe."
		return false
	if _est_equipe(identifiant_instance):
		derniere_erreur = "Desequipe cet objet avant de le desassembler."
		return false
	if inventaire == null or inventaire.obtenir_equipement_instance(identifiant_instance).is_empty():
		derniere_erreur = "Cette instance d'equipement n'est pas dans l'inventaire."
		return false
	return _obtenir_composants_desassemblage(objet).size() == DonneesInstanceEquipement.obtenir_composants_structurels(donnees).size()

func obtenir_composants_desassemblage() -> Array[Dictionary]:
	return _obtenir_composants_desassemblage(cible_desassemblage)

func desassembler() -> bool:
	derniere_erreur = ""
	if not peut_desassembler(cible_desassemblage):
		return false
	var donnees: Dictionary = cible_desassemblage.get("donnees", {})
	var identifiant_instance: StringName = donnees.get(DonneesInstanceEquipement.CLE_IDENTIFIANT_INSTANCE, &"")
	var equipement_retire: Dictionary = inventaire.retirer_equipement_instance(identifiant_instance)
	if equipement_retire.is_empty():
		derniere_erreur = "L'instance exacte n'a pas pu etre retiree."
		return false
	var composants_ajoutes: Array[Dictionary] = []
	for composant: Dictionary in _obtenir_composants_desassemblage(equipement_retire):
		if not inventaire.ajouter_depuis_payload(composant):
			for composant_ajoute: Dictionary in composants_ajoutes:
				inventaire.retirer_objet(composant_ajoute.get("identifiant", &""), int(composant_ajoute.get("quantite", 0)))
			inventaire.ajouter_depuis_payload(equipement_retire)
			derniere_erreur = "Le desassemblage a echoue. L'equipement exact a ete restaure."
			return false
		composants_ajoutes.append(composant)
	var objet_desassemble: Dictionary = equipement_retire.duplicate(true)
	annuler_desassemblage()
	desassemblage_reussi.emit(objet_desassemble)
	return true

func annuler_desassemblage() -> void:
	if cible_desassemblage.is_empty():
		return
	cible_desassemblage.clear()
	cible_desassemblage_changee.emit({})

func _actualiser_recette(emettre_table: bool = true) -> void:
	var nouvelle_recette: RecetteEquipement = _trouver_recette()
	var recette_a_change: bool = nouvelle_recette != recette_detectee
	recette_detectee = nouvelle_recette
	if emettre_table:
		table_changee.emit()
	if recette_a_change:
		recette_changee.emit(recette_detectee)

func _trouver_recette() -> RecetteEquipement:
	if catalogue_recettes == null:
		return null
	var quantites_table: Dictionary = table.obtenir_quantites()
	for recette: RecetteEquipement in catalogue_recettes.recettes:
		if recette == null or not recette.est_valide():
			continue
		var quantites_requises: Dictionary = recette.obtenir_quantites_composants()
		var quantite_totale: int = 0
		for quantite: Variant in quantites_requises.values():
			quantite_totale += int(quantite)
		if quantite_totale <= TableCraftInventaire.NOMBRE_SLOTS and quantites_requises == quantites_table:
			return recette
	return null

func _obtenir_composants_desassemblage(objet: Dictionary) -> Array[Dictionary]:
	var resultat: Array[Dictionary] = []
	if catalogue_recettes == null or objet.is_empty():
		return resultat
	var composants: Dictionary = DonneesInstanceEquipement.obtenir_composants_structurels(objet.get("donnees", {}))
	for identifiant: Variant in composants:
		var definition: LootItemEntry = catalogue_recettes.obtenir_definition(StringName(identifiant))
		var quantite: int = int(composants[identifiant])
		if definition == null or quantite <= 0:
			derniere_erreur = "La definition du composant %s est introuvable." % String(identifiant)
			continue
		resultat.append({"identifiant": definition.item_id, "nom": definition.nom_affiche, "icone": definition.icone, "quantite": quantite, "type_item": definition.type_item, "donnees": {"chemin_definition": definition.resource_path}})
	return resultat

func _est_equipe(identifiant_instance: StringName) -> bool:
	if gestionnaire_equipement == null:
		return false
	for index: int in GestionnaireEquipementJoueur.Emplacement.size():
		var objet: Dictionary = gestionnaire_equipement.obtenir_objet_equipe(index as GestionnaireEquipementJoueur.Emplacement)
		if objet.get("donnees", {}).get(DonneesInstanceEquipement.CLE_IDENTIFIANT_INSTANCE, &"") == identifiant_instance:
			return true
	return false
