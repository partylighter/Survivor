extends CanvasLayer
class_name InterfaceCommandeForge

@export_node_path("GestionnaireForge") var chemin_gestionnaire: NodePath

@onready var gestionnaire: GestionnaireForge = get_node_or_null(chemin_gestionnaire) as GestionnaireForge
@onready var invite: Label = $Invite
@onready var interface: Control = $Interface
@onready var titre: Label = $Interface/Panneau/Marge/Colonne/Titre
@onready var choix_commande: OptionButton = $Interface/Panneau/Marge/Colonne/ChoixCommande
@onready var objet: Label = $Interface/Panneau/Marge/Colonne/Objet
@onready var materiaux: Label = $Interface/Panneau/Marge/Colonne/Materiaux
@onready var etapes: Label = $Interface/Panneau/Marge/Colonne/Etapes
@onready var assemblage: Label = $Interface/Panneau/Marge/Colonne/Assemblage
@onready var difficulte: Label = $Interface/Panneau/Marge/Colonne/Difficulte
@onready var recompense: Label = $Interface/Panneau/Marge/Colonne/Recompense
@onready var etat: Label = $Interface/Panneau/Marge/Colonne/Etat
@onready var bouton_accepter: Button = $Interface/Panneau/Marge/Colonne/Boutons/Accepter
@onready var bouton_fermer: Button = $Interface/Panneau/Marge/Colonne/Boutons/Fermer

var contexte_actuel: StringName = &""
var message_action: String = ""

func _ready() -> void:
	interface.hide()
	invite.visible = false
	choix_commande.get_popup().always_on_top = true
	bouton_accepter.pressed.connect(_accepter_commande)
	bouton_fermer.pressed.connect(fermer)
	choix_commande.item_selected.connect(_selectionner_commande)
	if gestionnaire != null:
		gestionnaire.contexte_change.connect(_changer_contexte)
		gestionnaire.commande_changee.connect(_rafraichir)
		gestionnaire.fabrication_changee.connect(_actualiser_invite)
	else:
		push_error("GestionnaireForge introuvable. Verifie chemin_gestionnaire dans InterfaceCommandeForge.")

func ouvrir() -> void:
	interface.show()
	_rafraichir()

func fermer() -> void:
	interface.hide()

func _accepter_commande() -> void:
	if gestionnaire == null:
		return
	if gestionnaire.commande_est_active():
		var recompense_obtenue: int = gestionnaire.remettre_commande()
		message_action = "Commande terminée. Récompense : %d." % recompense_obtenue if recompense_obtenue > 0 else "La commande n'est pas encore terminée."
	else:
		message_action = "Commande acceptée." if gestionnaire.accepter_commande() else "Impossible d'accepter cette commande."
	_rafraichir()

func _rafraichir() -> void:
	if gestionnaire == null:
		return
	_actualiser_choix_commandes()
	var commande: DonneesCommandeForge = gestionnaire.obtenir_commande_affichee()
	if commande == null:
		titre.text = "AUCUNE DEMANDE"
		objet.text = ""
		materiaux.text = ""
		etapes.text = ""
		assemblage.text = ""
		difficulte.text = ""
		recompense.text = ""
		etat.text = ""
		bouton_accepter.disabled = true
		bouton_accepter.text = "Accepter"
		return
	titre.text = commande.nom
	var nom_objet: String = commande.objet_demande.nom_affiche if commande.objet_demande != null else "Objet manquant"
	objet.text = "Objet demandé : %s x%d" % [nom_objet, commande.quantite_demandee]
	materiaux.text = "Composants à fabriquer et matériaux :\n%s" % _texte_ingredients(commande)
	etapes.text = "Parcours des composants :\n%s" % _texte_etapes(commande)
	assemblage.text = _texte_assemblage(commande.recette_assemblage)
	difficulte.text = "Difficulté : %s" % _texte_difficulte(commande.difficulte)
	recompense.text = "Récompense : %d" % commande.prix
	var commande_valide: bool = commande.est_valide()
	if not commande_valide:
		etat.text = "Commande invalide : %s" % " ".join(commande.obtenir_erreurs())
	elif message_action != "":
		etat.text = message_action
	elif gestionnaire.commande_est_active():
		etat.text = "Commande en cours. Fabrique librement l'objet à la table de finition, puis reviens le remettre ici."
	else:
		etat.text = "État : %s" % _texte_etat(gestionnaire.obtenir_etat_commande())
	if gestionnaire.commande_est_active():
		var suivi: String = _texte_suivi_commande(commande)
		etat.text = "%s\n%s" % [message_action, suivi] if message_action != "" else suivi
	if gestionnaire.commande_est_active():
		var peut_remettre: bool = gestionnaire.commande_peut_etre_remise()
		bouton_accepter.disabled = not peut_remettre
		bouton_accepter.text = "Remettre la commande" if peut_remettre else "Commande en cours"
	else:
		bouton_accepter.disabled = not commande_valide
		bouton_accepter.text = "Accepter"

func _texte_suivi_commande(commande: DonneesCommandeForge) -> String:
	var lignes: PackedStringArray = []
	var inventaire: GestionnaireInventaire = gestionnaire.obtenir_inventaire_joueur_demandes()
	if gestionnaire.commande_peut_etre_remise():
		lignes.append("A FAIRE : remettre l'objet au client.")
	elif gestionnaire.fabrication_active != null:
		var etape: EtapeFabrication = gestionnaire.fabrication_active.obtenir_etape_actuelle()
		lignes.append("A FAIRE : %s." % _nom_etape(etape.type_etape) if etape != null else "A FAIRE : finaliser le composant.")
		var resultats: Dictionary = gestionnaire.obtenir_resultats_etapes_fabrication_active()
		if not resultats.is_empty():
			lignes.append("Étapes : %s" % _texte_resultats_etapes(resultats))
	else:
		var recette: RecetteComposant = gestionnaire.obtenir_recette_commande_active()
		if recette != null:
			lignes.append("A FAIRE : fabriquer %s (%s)." % [recette.resultat.nom_affiche, _nom_etape(recette.etapes[0].type_etape)])
		else:
			lignes.append("A FAIRE : assembler l'objet à la table de finition.")
	if commande.recette_assemblage != null and inventaire != null:
		var progression: PackedStringArray = []
		var quantites_requises: Dictionary = commande.recette_assemblage.obtenir_quantites_composants()
		for composant: LootItemEntry in commande.recette_assemblage.obtenir_composants_uniques():
			var requis: int = int(quantites_requises.get(composant.item_id, 0)) * commande.quantite_demandee
			progression.append("%s %d/%d" % [composant.nom_affiche, mini(inventaire.obtenir_quantite(composant.item_id), requis), requis])
		if not progression.is_empty():
			lignes.append("Composants : %s" % " | ".join(progression))
	var historique: Array[Dictionary] = gestionnaire.obtenir_historique_composants_fabriques()
	if not historique.is_empty():
		var dernier: Dictionary = historique.back()
		lignes.append("Dernier : %s — %s (%s)" % [dernier.get("nom", ""), String(dernier.get("qualite", "")).capitalize(), _texte_resultats_etapes(dernier.get("etapes", {}))])
	return "\n".join(lignes)

func _texte_resultats_etapes(resultats: Dictionary) -> String:
	var lignes: PackedStringArray = []
	for type_etape: int in [EtapeFabrication.TypeEtape.CHAUFFE, EtapeFabrication.TypeEtape.FONTE, EtapeFabrication.TypeEtape.MARTELAGE, EtapeFabrication.TypeEtape.MOULAGE]:
		if resultats.has(type_etape):
			lignes.append("%s : %s" % [_nom_etape(type_etape), String(resultats[type_etape]).capitalize()])
	return " | ".join(lignes)

func _actualiser_choix_commandes() -> void:
	choix_commande.clear()
	var commandes: Array[DonneesCommandeForge] = gestionnaire.obtenir_commandes_disponibles()
	for index: int in commandes.size():
		var commande: DonneesCommandeForge = commandes[index]
		var index_element: int = choix_commande.item_count
		choix_commande.add_item(commande.nom if commande != null else "Commande invalide")
		choix_commande.set_item_metadata(index_element, index)
	if not commandes.is_empty():
		for index_element: int in choix_commande.item_count:
			if int(choix_commande.get_item_metadata(index_element)) == gestionnaire.obtenir_index_commande_selectionnee():
				choix_commande.select(index_element)
				break
	choix_commande.disabled = gestionnaire.commande_est_active() or commandes.size() <= 1

func _selectionner_commande(index: int) -> void:
	if gestionnaire != null:
		message_action = ""
		gestionnaire.selectionner_commande(int(choix_commande.get_item_metadata(index)))

func _texte_ingredients(commande: DonneesCommandeForge) -> String:
	var lignes: PackedStringArray = []
	if commande.recette_assemblage != null:
		var quantites_composants: Dictionary = commande.recette_assemblage.obtenir_quantites_composants()
		for composant: LootItemEntry in commande.recette_assemblage.obtenir_composants_uniques():
			lignes.append("- %s x%d" % [composant.nom_affiche, int(quantites_composants.get(composant.item_id, 0))])
		for recette_composant: RecetteComposant in commande.recettes_composants:
			if recette_composant == null:
				continue
			for ingredient: IngredientRecette in recette_composant.ingredients:
				if ingredient != null and ingredient.objet != null:
					lignes.append("  %s : %s x%d" % [recette_composant.resultat.nom_affiche, ingredient.objet.nom_affiche, ingredient.quantite])
	elif commande.recette != null:
		for ingredient: IngredientRecette in commande.recette.ingredients:
			if ingredient != null and ingredient.objet != null:
				lignes.append("- %s x%d" % [ingredient.objet.nom_affiche, ingredient.quantite])
	return "\n".join(lignes) if not lignes.is_empty() else "Aucun"

func _texte_etapes(commande: DonneesCommandeForge) -> String:
	var parcours: PackedStringArray = []
	var recettes: Array[RecetteComposant] = commande.recettes_composants
	if recettes.is_empty() and commande.recette != null:
		recettes = [commande.recette]
	for recette_composant: RecetteComposant in recettes:
		var noms: PackedStringArray = []
		for etape_fabrication: EtapeFabrication in recette_composant.etapes:
			if etape_fabrication != null:
				noms.append(_nom_etape(etape_fabrication.type_etape))
		parcours.append("%s : %s" % [recette_composant.resultat.nom_affiche, " -> ".join(noms)])
	if commande.recette_assemblage != null:
		parcours.append("Assemblage final")
	return "\n".join(parcours) if not parcours.is_empty() else "Aucune"

func _texte_assemblage(recette_assemblage: RecetteEquipement) -> String:
	if recette_assemblage == null:
		return "Assemblage : aucun"
	var lignes: PackedStringArray = []
	for y: int in recette_assemblage.hauteur_motif:
		var ligne: PackedStringArray = []
		for x: int in recette_assemblage.largeur_motif:
			var composant: LootItemEntry = recette_assemblage.motif[y * recette_assemblage.largeur_motif + x]
			ligne.append("[%s]" % composant.nom_affiche if composant != null else "[ ]")
		lignes.append(" ".join(ligne))
	var decalage: String = " Le motif peut etre decale dans la grille." if recette_assemblage.autoriser_decalage else ""
	return "Assemblage a la table de finition :\n%s%s" % ["\n".join(lignes), decalage]

func _nom_etape(type_etape: EtapeFabrication.TypeEtape) -> String:
	match type_etape:
		EtapeFabrication.TypeEtape.CHAUFFE:
			return "Chauffe"
		EtapeFabrication.TypeEtape.FONTE:
			return "Fonte"
		EtapeFabrication.TypeEtape.MOULAGE:
			return "Moulage"
		EtapeFabrication.TypeEtape.MARTELAGE:
			return "Martelage"
	return "Inconnue"

func _texte_difficulte(valeur: DonneesCommandeForge.Difficulte) -> String:
	match valeur:
		DonneesCommandeForge.Difficulte.FACILE:
			return "Facile"
		DonneesCommandeForge.Difficulte.NORMALE:
			return "Normale"
		DonneesCommandeForge.Difficulte.DIFFICILE:
			return "Difficile"
	return "Inconnue"

func _texte_etat(valeur: CommandeForgeActive.Etat) -> String:
	match valeur:
		CommandeForgeActive.Etat.EN_ATTENTE:
			return "En attente"
		CommandeForgeActive.Etat.EN_COURS:
			return "En cours"
		CommandeForgeActive.Etat.TERMINEE:
			return "Terminée"
		CommandeForgeActive.Etat.REMUNEREE:
			return "Rémunérée"
	return "Inconnu"

func _changer_contexte(nouveau_contexte: StringName) -> void:
	contexte_actuel = nouveau_contexte
	_actualiser_invite()

func _actualiser_invite() -> void:
	if contexte_actuel == GestionnaireForge.CONTEXTE_DEMANDES:
		invite.text = "E - Consulter les demandes"
	elif contexte_actuel == GestionnaireForge.CONTEXTE_MARTELAGE:
		invite.text = "E - Commencer le martelage" if gestionnaire != null and gestionnaire.martelage_est_disponible() else ""
	elif contexte_actuel == GestionnaireForge.CONTEXTE_FONTE:
		if gestionnaire != null and gestionnaire.fonte_est_disponible():
			invite.text = "E - Commencer la fonte" if gestionnaire.fabrication_active != null else "E - Préparer la fonte"
		else:
			invite.text = ""
	elif contexte_actuel == GestionnaireForge.CONTEXTE_MOULAGE:
		invite.text = "E - Commencer le moulage" if gestionnaire != null and gestionnaire.moulage_est_disponible() else ""
	elif contexte_actuel == GestionnaireForge.CONTEXTE_ASSEMBLAGE:
		invite.text = "E - Commencer l'assemblage" if gestionnaire != null and gestionnaire.assemblage_est_disponible() else ""
	elif contexte_actuel == GestionnaireForge.CONTEXTE_CHAUFFE:
		if gestionnaire != null and gestionnaire.chauffe_est_disponible():
			invite.text = "E - Commencer la chauffe" if gestionnaire.fabrication_active != null else "E - Préparer la chauffe"
		else:
			invite.text = ""
	else:
		invite.text = ""
	invite.visible = invite.text != ""
