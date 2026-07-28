extends Node2D
class_name GestionnaireForge

signal contexte_change(contexte: StringName)
signal commande_changee
signal fabrication_changee

const CONTEXTE_AUCUN: StringName = &""
const CONTEXTE_CHAUFFE: StringName = &"chauffe"
const CONTEXTE_DEMANDES: StringName = &"demandes"
const CONTEXTE_MARTELAGE: StringName = &"martelage"
const CONTEXTE_FONTE: StringName = &"fonte"
const CONTEXTE_MOULAGE: StringName = &"moulage"
const CONTEXTE_ASSEMBLAGE: StringName = &"assemblage"
const CONTEXTE_RESERVE: StringName = &"reserve"
const RESULTAT_ECHEC_MOULAGE: StringName = &"echec"
const META_INTERACTION_FORGE: StringName = &"interaction_forge_active"

@export_node_path("Area2D") var chemin_zone_chauffe: NodePath
@export_node_path("Area2D") var chemin_zone_demandes: NodePath
@export_node_path("Area2D") var chemin_zone_martelage: NodePath
@export_node_path("Area2D") var chemin_zone_fonte: NodePath
@export_node_path("Area2D") var chemin_zone_moulage: NodePath
@export_node_path("Area2D") var chemin_zone_assemblage: NodePath
@export_node_path("Area2D") var chemin_zone_reserve: NodePath
@export_node_path("InterfaceCommandeForge") var chemin_interface_commande: NodePath
@export_node_path("InterfacePreparationForge") var chemin_interface_preparation: NodePath
@export_node_path("InterfaceChauffeForge") var chemin_interface_chauffe: NodePath
@export_node_path("InterfaceMartelageForge") var chemin_interface_martelage: NodePath
@export_node_path("InterfaceFonteForge") var chemin_interface_fonte: NodePath
@export_node_path("InterfaceMoulageForge") var chemin_interface_moulage: NodePath
@export_node_path("InterfaceAssemblageForge") var chemin_interface_assemblage: NodePath
@export_node_path("InterfaceCoffreReserve") var chemin_interface_coffre_reserve: NodePath
@export var commande_disponible: DonneesCommandeForge
@export var commandes_disponibles: Array[DonneesCommandeForge] = []
@export var action_interagir: StringName = &"interagir"

@onready var zone_chauffe: Area2D = get_node_or_null(chemin_zone_chauffe) as Area2D
@onready var zone_demandes: Area2D = get_node_or_null(chemin_zone_demandes) as Area2D
@onready var zone_martelage: Area2D = get_node_or_null(chemin_zone_martelage) as Area2D
@onready var zone_fonte: Area2D = get_node_or_null(chemin_zone_fonte) as Area2D
@onready var zone_moulage: Area2D = get_node_or_null(chemin_zone_moulage) as Area2D
@onready var zone_assemblage: Area2D = get_node_or_null(chemin_zone_assemblage) as Area2D
@onready var zone_reserve: Area2D = get_node_or_null(chemin_zone_reserve) as Area2D
@onready var interface_commande: InterfaceCommandeForge = get_node_or_null(chemin_interface_commande) as InterfaceCommandeForge
@onready var interface_preparation: InterfacePreparationForge = get_node_or_null(chemin_interface_preparation) as InterfacePreparationForge
@onready var interface_chauffe: InterfaceChauffeForge = get_node_or_null(chemin_interface_chauffe) as InterfaceChauffeForge
@onready var interface_martelage: InterfaceMartelageForge = get_node_or_null(chemin_interface_martelage) as InterfaceMartelageForge
@onready var interface_fonte: InterfaceFonteForge = get_node_or_null(chemin_interface_fonte) as InterfaceFonteForge
@onready var interface_moulage: InterfaceMoulageForge = get_node_or_null(chemin_interface_moulage) as InterfaceMoulageForge
@onready var interface_assemblage: InterfaceAssemblageForge = get_node_or_null(chemin_interface_assemblage) as InterfaceAssemblageForge
@onready var interface_coffre_reserve: InterfaceCoffreReserve = get_node_or_null(chemin_interface_coffre_reserve) as InterfaceCoffreReserve

var commande_active: CommandeForgeActive
var fabrication_active: FabricationActive
var recette_composant_selectionnee: RecetteComposant
var joueur_zone_chauffe: Player
var joueur_zone_demandes: Player
var joueur_zone_martelage: Player
var joueur_zone_fonte: Player
var joueur_zone_moulage: Player
var joueur_zone_assemblage: Player
var joueur_zone_reserve: Player
var preparation_active: bool = false
var poste_preparation_actuel: int = -1
var derniere_erreur_preparation: String = ""
var index_commande_selectionnee: int = 0
var dernier_resultat_fabrication: Dictionary = {}
var historique_composants_fabriques: Array[Dictionary] = []
var derniere_recompense: int = 0

func _ready() -> void:
	_verifier_configuration()
	if zone_chauffe != null:
		zone_chauffe.body_entered.connect(_quand_joueur_entre_zone_chauffe)
		zone_chauffe.body_exited.connect(_quand_joueur_sort_zone_chauffe)
	if zone_demandes != null:
		zone_demandes.body_entered.connect(_quand_joueur_entre_zone_demandes)
		zone_demandes.body_exited.connect(_quand_joueur_sort_zone_demandes)
	if zone_martelage != null:
		zone_martelage.body_entered.connect(_quand_joueur_entre_zone_martelage)
		zone_martelage.body_exited.connect(_quand_joueur_sort_zone_martelage)
	if zone_fonte != null:
		zone_fonte.body_entered.connect(_quand_joueur_entre_zone_fonte)
		zone_fonte.body_exited.connect(_quand_joueur_sort_zone_fonte)
	if zone_moulage != null:
		zone_moulage.body_entered.connect(_quand_joueur_entre_zone_moulage)
		zone_moulage.body_exited.connect(_quand_joueur_sort_zone_moulage)
	if zone_assemblage != null:
		zone_assemblage.body_entered.connect(_quand_joueur_entre_zone_assemblage)
		zone_assemblage.body_exited.connect(_quand_joueur_sort_zone_assemblage)
	if zone_reserve != null:
		zone_reserve.body_entered.connect(_quand_joueur_entre_zone_reserve)
		zone_reserve.body_exited.connect(_quand_joueur_sort_zone_reserve)

func _exit_tree() -> void:
	_fermer_interfaces_sauf(null)
	if joueur_zone_chauffe != null and is_instance_valid(joueur_zone_chauffe):
		joueur_zone_chauffe.set_meta(META_INTERACTION_FORGE, false)
	if joueur_zone_demandes != null and is_instance_valid(joueur_zone_demandes):
		joueur_zone_demandes.set_meta(META_INTERACTION_FORGE, false)
	if joueur_zone_martelage != null and is_instance_valid(joueur_zone_martelage):
		joueur_zone_martelage.set_meta(META_INTERACTION_FORGE, false)
	if joueur_zone_fonte != null and is_instance_valid(joueur_zone_fonte):
		joueur_zone_fonte.set_meta(META_INTERACTION_FORGE, false)
	if joueur_zone_moulage != null and is_instance_valid(joueur_zone_moulage):
		joueur_zone_moulage.set_meta(META_INTERACTION_FORGE, false)
	if joueur_zone_assemblage != null and is_instance_valid(joueur_zone_assemblage):
		joueur_zone_assemblage.set_meta(META_INTERACTION_FORGE, false)
	if joueur_zone_reserve != null and is_instance_valid(joueur_zone_reserve):
		joueur_zone_reserve.set_meta(META_INTERACTION_FORGE, false)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(action_interagir):
		return
	if _une_interface_est_ouverte():
		get_viewport().set_input_as_handled()
		return
	if joueur_zone_demandes != null:
		if interface_commande == null:
			push_error("InterfaceCommandeForge introuvable. Verifie chemin_interface_commande.")
			return
		_fermer_interfaces_sauf(interface_commande)
		interface_commande.ouvrir()
	elif joueur_zone_martelage != null:
		if not demarrer_martelage():
			return
	elif joueur_zone_fonte != null:
		if fabrication_active == null:
			if not _ouvrir_preparation(EtapeFabrication.TypeEtape.FONTE):
				return
		elif not demarrer_fonte():
			return
	elif joueur_zone_moulage != null:
		if not demarrer_moulage():
			return
	elif joueur_zone_assemblage != null:
		if not demarrer_assemblage():
			return
	elif joueur_zone_reserve != null:
		if interface_coffre_reserve == null:
			push_error("InterfaceCoffreReserve introuvable. Verifie chemin_interface_coffre_reserve.")
			return
		_fermer_interfaces_sauf(interface_coffre_reserve)
		interface_coffre_reserve.ouvrir()
	elif joueur_zone_chauffe != null:
		if fabrication_active == null:
			if not _ouvrir_preparation(EtapeFabrication.TypeEtape.CHAUFFE):
				return
		elif not demarrer_chauffe():
			return
	else:
		return
	get_viewport().set_input_as_handled()

func accepter_commande() -> bool:
	var commande_selectionnee: DonneesCommandeForge = obtenir_commande_selectionnee()
	if commande_active != null or commande_selectionnee == null:
		return false
	var nouvelle_commande := CommandeForgeActive.new()
	if not nouvelle_commande.initialiser(commande_selectionnee):
		return false
	if not nouvelle_commande.demarrer():
		return false
	commande_active = nouvelle_commande
	recette_composant_selectionnee = null
	derniere_recompense = 0
	dernier_resultat_fabrication.clear()
	historique_composants_fabriques.clear()
	commande_changee.emit()
	return true

func commande_peut_etre_remise() -> bool:
	if commande_active == null or commande_active.donnees == null or fabrication_active != null:
		return false
	return commande_active.peut_terminer(obtenir_inventaire_joueur_demandes())

func remettre_commande() -> int:
	if not commande_peut_etre_remise():
		return 0
	var inventaire: GestionnaireInventaire = obtenir_inventaire_joueur_demandes()
	var identifiant: StringName = commande_active.donnees.objet_demande.item_id
	var quantite: int = commande_active.donnees.quantite_demandee
	if not commande_active.terminer(inventaire):
		return 0
	if inventaire.retirer_objet(identifiant, quantite) != quantite:
		return 0
	derniere_recompense = commande_active.recuperer_recompense()
	var commande_remise: DonneesCommandeForge = commande_active.donnees
	commandes_disponibles.erase(commande_remise)
	if commande_disponible == commande_remise:
		commande_disponible = null
	commande_active = null
	recette_composant_selectionnee = null
	dernier_resultat_fabrication.clear()
	historique_composants_fabriques.clear()
	commande_changee.emit()
	return derniere_recompense

func obtenir_commande_affichee() -> DonneesCommandeForge:
	if commande_active != null:
		return commande_active.donnees
	return obtenir_commande_selectionnee()

func obtenir_commandes_disponibles() -> Array[DonneesCommandeForge]:
	if not commandes_disponibles.is_empty():
		return commandes_disponibles
	var commandes: Array[DonneesCommandeForge] = []
	if commande_disponible != null:
		commandes.append(commande_disponible)
	return commandes

func obtenir_commande_selectionnee() -> DonneesCommandeForge:
	var commandes: Array[DonneesCommandeForge] = obtenir_commandes_disponibles()
	if commandes.is_empty():
		return null
	index_commande_selectionnee = clampi(index_commande_selectionnee, 0, commandes.size() - 1)
	return commandes[index_commande_selectionnee]

func obtenir_index_commande_selectionnee() -> int:
	return index_commande_selectionnee

func selectionner_commande(index: int) -> bool:
	var commandes: Array[DonneesCommandeForge] = obtenir_commandes_disponibles()
	if commande_active != null or index < 0 or index >= commandes.size():
		return false
	index_commande_selectionnee = index
	commande_changee.emit()
	return true

func commande_est_active() -> bool:
	return commande_active != null

func obtenir_etat_commande() -> CommandeForgeActive.Etat:
	if commande_active == null:
		return CommandeForgeActive.Etat.EN_ATTENTE
	return commande_active.etat

func obtenir_recette_commande_active() -> RecetteComposant:
	if commande_active == null or commande_active.etat != CommandeForgeActive.Etat.EN_COURS:
		return null
	if recette_composant_selectionnee != null:
		return recette_composant_selectionnee
	return _trouver_recette_composant_a_fabriquer()

func obtenir_recettes_composants_commande_active() -> Array[RecetteComposant]:
	var recettes: Array[RecetteComposant] = []
	if commande_active == null or commande_active.donnees == null:
		return recettes
	if not commande_active.donnees.recettes_composants.is_empty():
		return commande_active.donnees.recettes_composants
	if commande_active.donnees.recette != null:
		recettes.append(commande_active.donnees.recette)
	return recettes

func obtenir_recette_assemblage_commande_active() -> RecetteEquipement:
	if commande_active == null or commande_active.etat != CommandeForgeActive.Etat.EN_COURS:
		return null
	return commande_active.donnees.recette_assemblage

func obtenir_resultats_etapes_fabrication_active() -> Dictionary:
	return fabrication_active.resultats_etapes.duplicate(true) if fabrication_active != null else {}

func obtenir_historique_composants_fabriques() -> Array[Dictionary]:
	return historique_composants_fabriques.duplicate(true)

func obtenir_inventaire_joueur_preparation() -> GestionnaireInventaire:
	var joueur: Player
	if poste_preparation_actuel == EtapeFabrication.TypeEtape.CHAUFFE:
		joueur = joueur_zone_chauffe
	elif poste_preparation_actuel == EtapeFabrication.TypeEtape.FONTE:
		joueur = joueur_zone_fonte
	return _obtenir_inventaire_joueur(joueur)

func obtenir_inventaire_joueur_reserve() -> GestionnaireInventaire:
	return _obtenir_inventaire_joueur(joueur_zone_reserve)

func obtenir_inventaire_joueur_demandes() -> GestionnaireInventaire:
	return _obtenir_inventaire_joueur(joueur_zone_demandes)

func obtenir_inventaire_joueur_assemblage() -> GestionnaireInventaire:
	return _obtenir_inventaire_joueur(joueur_zone_assemblage)

func preparer_fabrication(selection: Dictionary) -> bool:
	derniere_erreur_preparation = ""
	if fabrication_active != null:
		derniere_erreur_preparation = "Une fabrication est deja preparee."
		return false
	var recette: RecetteComposant = obtenir_recette_commande_active()
	if recette == null:
		derniere_erreur_preparation = "Aucune commande active."
		return false
	if not recette.est_valide():
		derniere_erreur_preparation = "La recette de la commande est invalide."
		return false
	var inventaire: GestionnaireInventaire = obtenir_inventaire_joueur_preparation()
	if inventaire == null:
		derniere_erreur_preparation = "Inventaire introuvable."
		return false
	if selection.size() != recette.ingredients.size():
		derniere_erreur_preparation = "La selection ne correspond pas a la recette."
		return false
	for ingredient: IngredientRecette in recette.ingredients:
		if ingredient == null or ingredient.objet == null:
			derniere_erreur_preparation = "La recette contient un ingredient invalide."
			return false
		var quantite_selectionnee: int = int(selection.get(ingredient.objet.item_id, 0))
		if quantite_selectionnee != ingredient.quantite:
			derniere_erreur_preparation = "Selection invalide pour %s." % ingredient.objet.nom_affiche
			return false
		if inventaire.obtenir_quantite(ingredient.objet.item_id) < quantite_selectionnee:
			derniere_erreur_preparation = "Materiaux insuffisants."
			return false
	var nouvelle_fabrication := FabricationActive.new()
	if not nouvelle_fabrication.initialiser(recette, commande_active.donnees.difficulte, selection):
		derniere_erreur_preparation = "Impossible de preparer la fabrication."
		return false
	fabrication_active = nouvelle_fabrication
	fabrication_changee.emit()
	return true

func demarrer_chauffe() -> bool:
	if fabrication_active == null:
		return false
	var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
	if etape == null or etape.type_etape != EtapeFabrication.TypeEtape.CHAUFFE:
		return false
	if interface_chauffe == null:
		push_error("InterfaceChauffeForge introuvable. Verifie chemin_interface_chauffe.")
		return false
	_fermer_interfaces_sauf(interface_chauffe)
	var demarree: bool = interface_chauffe.ouvrir()
	if demarree:
		preparation_active = false
		poste_preparation_actuel = -1
	return demarree

func chauffe_est_disponible() -> bool:
	if fabrication_active != null:
		var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
		return etape != null and etape.type_etape == EtapeFabrication.TypeEtape.CHAUFFE
	return _recette_commence_par(EtapeFabrication.TypeEtape.CHAUFFE)

func terminer_chauffe(resultat: StringName) -> void:
	if fabrication_active == null:
		return
	var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
	if etape == null or etape.type_etape != EtapeFabrication.TypeEtape.CHAUFFE:
		return
	fabrication_active.enregistrer_resultat_etape(EtapeFabrication.TypeEtape.CHAUFFE, resultat)
	if resultat != GestionnaireChauffe.RESULTAT_ECHEC:
		fabrication_active.avancer_etape()
	fabrication_changee.emit()

func demarrer_martelage() -> bool:
	if fabrication_active == null:
		return false
	var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
	if etape == null or etape.type_etape != EtapeFabrication.TypeEtape.MARTELAGE:
		return false
	if interface_martelage == null:
		push_error("InterfaceMartelageForge introuvable. Verifie chemin_interface_martelage.")
		return false
	_fermer_interfaces_sauf(interface_martelage)
	return interface_martelage.ouvrir()

func martelage_est_disponible() -> bool:
	if fabrication_active == null:
		return false
	var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
	return etape != null and etape.type_etape == EtapeFabrication.TypeEtape.MARTELAGE

func terminer_martelage(resultat: StringName) -> void:
	if fabrication_active == null:
		return
	var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
	if etape == null or etape.type_etape != EtapeFabrication.TypeEtape.MARTELAGE:
		return
	fabrication_active.enregistrer_resultat_etape(EtapeFabrication.TypeEtape.MARTELAGE, resultat)
	if resultat != GestionnaireMartelage.RESULTAT_ECHEC:
		fabrication_active.avancer_etape()
		if fabrication_active.est_terminee():
			_finaliser_composant(_obtenir_inventaire_joueur(joueur_zone_martelage))
	fabrication_changee.emit()

func demarrer_fonte() -> bool:
	if fabrication_active == null:
		return false
	var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
	if etape == null or etape.type_etape != EtapeFabrication.TypeEtape.FONTE:
		return false
	if interface_fonte == null:
		push_error("InterfaceFonteForge introuvable. Verifie chemin_interface_fonte.")
		return false
	_fermer_interfaces_sauf(interface_fonte)
	var demarree: bool = interface_fonte.ouvrir()
	if demarree:
		preparation_active = false
		poste_preparation_actuel = -1
	return demarree

func fonte_est_disponible() -> bool:
	if fabrication_active != null:
		var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
		return etape != null and etape.type_etape == EtapeFabrication.TypeEtape.FONTE
	return _recette_commence_par(EtapeFabrication.TypeEtape.FONTE)

func terminer_fonte(resultat: StringName) -> void:
	if fabrication_active == null:
		return
	var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
	if etape == null or etape.type_etape != EtapeFabrication.TypeEtape.FONTE:
		return
	fabrication_active.enregistrer_resultat_etape(EtapeFabrication.TypeEtape.FONTE, resultat)
	if resultat != GestionnaireFonte.RESULTAT_ECHEC:
		fabrication_active.avancer_etape()
	fabrication_changee.emit()

func demarrer_moulage() -> bool:
	if fabrication_active == null:
		return false
	var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
	if etape == null or etape.type_etape != EtapeFabrication.TypeEtape.MOULAGE:
		return false
	if interface_moulage == null:
		push_error("InterfaceMoulageForge introuvable. Verifie chemin_interface_moulage.")
		return false
	_fermer_interfaces_sauf(interface_moulage)
	return interface_moulage.ouvrir()

func moulage_est_disponible() -> bool:
	if fabrication_active == null:
		return false
	var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
	return etape != null and etape.type_etape == EtapeFabrication.TypeEtape.MOULAGE

func terminer_moulage(resultat: StringName) -> void:
	if fabrication_active == null:
		return
	var etape: EtapeFabrication = fabrication_active.obtenir_etape_actuelle()
	if etape == null or etape.type_etape != EtapeFabrication.TypeEtape.MOULAGE:
		return
	fabrication_active.enregistrer_resultat_etape(EtapeFabrication.TypeEtape.MOULAGE, resultat)
	if resultat != RESULTAT_ECHEC_MOULAGE:
		fabrication_active.avancer_etape()
		if fabrication_active.est_terminee():
			_finaliser_composant(_obtenir_inventaire_joueur(joueur_zone_moulage))
	fabrication_changee.emit()

func demarrer_assemblage() -> bool:
	if not assemblage_est_disponible():
		return false
	if interface_assemblage == null:
		push_error("InterfaceAssemblageForge introuvable. Verifie chemin_interface_assemblage.")
		return false
	_fermer_interfaces_sauf(interface_assemblage)
	return interface_assemblage.ouvrir()

func assemblage_est_disponible() -> bool:
	return fabrication_active == null and obtenir_inventaire_joueur_assemblage() != null

func terminer_assemblage(resultat: Dictionary) -> void:
	if resultat.is_empty():
		return
	dernier_resultat_fabrication = resultat.duplicate(true)
	fabrication_changee.emit()

func fermer_interfaces_forge() -> void:
	preparation_active = false
	poste_preparation_actuel = -1
	_fermer_interfaces_sauf(null)
	_actualiser_contexte()

func _quand_joueur_entre_zone_chauffe(corps: Node) -> void:
	var joueur := _obtenir_joueur(corps)
	if joueur == null:
		return
	joueur_zone_chauffe = joueur
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_sort_zone_chauffe(corps: Node) -> void:
	if corps != joueur_zone_chauffe:
		return
	var joueur := joueur_zone_chauffe
	joueur_zone_chauffe = null
	if preparation_active and poste_preparation_actuel == EtapeFabrication.TypeEtape.CHAUFFE:
		preparation_active = false
		poste_preparation_actuel = -1
		if interface_preparation != null:
			interface_preparation.fermer()
	if interface_chauffe != null:
		interface_chauffe.fermer()
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_entre_zone_demandes(corps: Node) -> void:
	var joueur := _obtenir_joueur(corps)
	if joueur == null:
		return
	joueur_zone_demandes = joueur
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_sort_zone_demandes(corps: Node) -> void:
	if corps != joueur_zone_demandes:
		return
	var joueur := joueur_zone_demandes
	joueur_zone_demandes = null
	if interface_commande != null:
		interface_commande.fermer()
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_entre_zone_martelage(corps: Node) -> void:
	var joueur := _obtenir_joueur(corps)
	if joueur == null:
		return
	joueur_zone_martelage = joueur
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_sort_zone_martelage(corps: Node) -> void:
	if corps != joueur_zone_martelage:
		return
	var joueur := joueur_zone_martelage
	joueur_zone_martelage = null
	if interface_martelage != null:
		interface_martelage.fermer()
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_entre_zone_fonte(corps: Node) -> void:
	var joueur := _obtenir_joueur(corps)
	if joueur == null:
		return
	joueur_zone_fonte = joueur
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_sort_zone_fonte(corps: Node) -> void:
	if corps != joueur_zone_fonte:
		return
	var joueur := joueur_zone_fonte
	joueur_zone_fonte = null
	if preparation_active and poste_preparation_actuel == EtapeFabrication.TypeEtape.FONTE:
		preparation_active = false
		poste_preparation_actuel = -1
		if interface_preparation != null:
			interface_preparation.fermer()
	if interface_fonte != null:
		interface_fonte.fermer()
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_entre_zone_moulage(corps: Node) -> void:
	var joueur := _obtenir_joueur(corps)
	if joueur == null:
		return
	joueur_zone_moulage = joueur
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_sort_zone_moulage(corps: Node) -> void:
	if corps != joueur_zone_moulage:
		return
	var joueur := joueur_zone_moulage
	joueur_zone_moulage = null
	if interface_moulage != null:
		interface_moulage.fermer()
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_entre_zone_assemblage(corps: Node) -> void:
	var joueur := _obtenir_joueur(corps)
	if joueur == null:
		return
	joueur_zone_assemblage = joueur
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_sort_zone_assemblage(corps: Node) -> void:
	if corps != joueur_zone_assemblage:
		return
	var joueur := joueur_zone_assemblage
	joueur_zone_assemblage = null
	if interface_assemblage != null:
		interface_assemblage.fermer()
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_entre_zone_reserve(corps: Node) -> void:
	var joueur := _obtenir_joueur(corps)
	if joueur == null:
		return
	joueur_zone_reserve = joueur
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _quand_joueur_sort_zone_reserve(corps: Node) -> void:
	if corps != joueur_zone_reserve:
		return
	var joueur := joueur_zone_reserve
	joueur_zone_reserve = null
	if interface_coffre_reserve != null:
		interface_coffre_reserve.fermer()
	_actualiser_blocage_ramassage(joueur)
	_actualiser_contexte()

func _obtenir_joueur(corps: Node) -> Player:
	if corps is Player and corps.is_in_group(&"joueur_principal"):
		return corps as Player
	return null

func _obtenir_inventaire_joueur(joueur: Player) -> GestionnaireInventaire:
	if joueur == null or not is_instance_valid(joueur):
		return null
	if joueur.inventaire != null:
		return joueur.inventaire
	return joueur.find_child("GestionnaireInventaire", true, false) as GestionnaireInventaire

func _actualiser_blocage_ramassage(joueur: Player) -> void:
	if joueur == null or not is_instance_valid(joueur):
		return
	var interaction_active: bool = joueur == joueur_zone_chauffe or joueur == joueur_zone_demandes or joueur == joueur_zone_martelage or joueur == joueur_zone_fonte or joueur == joueur_zone_moulage or joueur == joueur_zone_assemblage or joueur == joueur_zone_reserve
	joueur.set_meta(META_INTERACTION_FORGE, interaction_active)

func _actualiser_contexte() -> void:
	if joueur_zone_demandes != null:
		contexte_change.emit(CONTEXTE_DEMANDES)
	elif joueur_zone_martelage != null:
		contexte_change.emit(CONTEXTE_MARTELAGE)
	elif joueur_zone_fonte != null:
		contexte_change.emit(CONTEXTE_FONTE)
	elif joueur_zone_moulage != null:
		contexte_change.emit(CONTEXTE_MOULAGE)
	elif joueur_zone_assemblage != null:
		contexte_change.emit(CONTEXTE_ASSEMBLAGE)
	elif joueur_zone_reserve != null:
		contexte_change.emit(CONTEXTE_RESERVE)
	elif joueur_zone_chauffe != null:
		contexte_change.emit(CONTEXTE_CHAUFFE)
	else:
		contexte_change.emit(CONTEXTE_AUCUN)

func _ouvrir_preparation(type_poste: EtapeFabrication.TypeEtape) -> bool:
	if interface_preparation == null:
		push_error("InterfacePreparationForge introuvable. Verifie chemin_interface_preparation.")
		return false
	recette_composant_selectionnee = _trouver_recette_composant_a_fabriquer(type_poste)
	if recette_composant_selectionnee == null:
		return false
	_fermer_interfaces_sauf(interface_preparation)
	preparation_active = true
	poste_preparation_actuel = type_poste
	interface_preparation.ouvrir(type_poste)
	_actualiser_contexte()
	return true

func _recette_commence_par(type_etape: EtapeFabrication.TypeEtape) -> bool:
	return _trouver_recette_composant_a_fabriquer(type_etape) != null

func _trouver_recette_composant_a_fabriquer(type_etape: int = -1) -> RecetteComposant:
	var recettes: Array[RecetteComposant] = obtenir_recettes_composants_commande_active()
	if recettes.is_empty():
		return null
	var inventaire: GestionnaireInventaire = _obtenir_inventaire_forge()
	var recette_assemblage: RecetteEquipement = obtenir_recette_assemblage_commande_active()
	for recette_composant: RecetteComposant in recettes:
		if recette_composant == null or recette_composant.etapes.is_empty() or recette_composant.etapes[0] == null:
			continue
		if type_etape >= 0 and recette_composant.etapes[0].type_etape != type_etape:
			continue
		if recette_assemblage == null:
			return recette_composant
		var quantites_requises: Dictionary = recette_assemblage.obtenir_quantites_composants()
		var quantite_requise: int = int(quantites_requises.get(recette_composant.resultat.item_id, 0)) * commande_active.donnees.quantite_demandee
		var quantite_possedee: int = inventaire.obtenir_quantite(recette_composant.resultat.item_id) if inventaire != null else 0
		if quantite_possedee < quantite_requise:
			return recette_composant
	return null

func _obtenir_inventaire_forge() -> GestionnaireInventaire:
	var joueurs: Array[Player] = [joueur_zone_chauffe, joueur_zone_demandes, joueur_zone_martelage, joueur_zone_fonte, joueur_zone_moulage, joueur_zone_assemblage, joueur_zone_reserve]
	for joueur: Player in joueurs:
		var inventaire: GestionnaireInventaire = _obtenir_inventaire_joueur(joueur)
		if inventaire != null:
			return inventaire
	return null

func _finaliser_composant(inventaire: GestionnaireInventaire) -> bool:
	if fabrication_active == null or not fabrication_active.est_prete_assemblage() or inventaire == null:
		return false
	for identifiant: Variant in fabrication_active.materiaux_selectionnes:
		if inventaire.obtenir_quantite(identifiant) < int(fabrication_active.materiaux_selectionnes[identifiant]):
			return false
	for identifiant: Variant in fabrication_active.materiaux_selectionnes:
		inventaire.retirer_objet(identifiant, int(fabrication_active.materiaux_selectionnes[identifiant]))
	var recette: RecetteComposant = fabrication_active.recette
	var qualite: StringName = fabrication_active.calculer_qualite_finale()
	historique_composants_fabriques.append({"nom": recette.resultat.nom_affiche, "qualite": qualite, "etapes": fabrication_active.resultats_etapes.duplicate(true)})
	inventaire.ajouter_objet(recette.resultat.item_id, recette.resultat.nom_affiche, recette.quantite_resultat, recette.resultat.icone, Loot.TypeItem.COMPOSANT, {"qualite": qualite, "recette": recette.identifiant})
	dernier_resultat_fabrication = {"identifiant": recette.resultat.item_id, "nom": recette.resultat.nom_affiche, "quantite": recette.quantite_resultat, "qualite": qualite}
	fabrication_active.finalisee = true
	fabrication_active = null
	recette_composant_selectionnee = null
	return true

func _une_interface_est_ouverte() -> bool:
	return (
		interface_commande != null and interface_commande.interface.visible
		or interface_preparation != null and interface_preparation.interface.visible
		or interface_chauffe != null and interface_chauffe.interface.visible
		or interface_martelage != null and interface_martelage.interface.visible
		or interface_fonte != null and interface_fonte.interface.visible
		or interface_moulage != null and interface_moulage.interface.visible
		or interface_assemblage != null and interface_assemblage.interface.visible
		or interface_coffre_reserve != null and interface_coffre_reserve.interface.visible
	)

func _fermer_interfaces_sauf(interface_conservee: CanvasLayer) -> void:
	if interface_commande != null and interface_commande != interface_conservee:
		interface_commande.fermer()
	if interface_preparation != null and interface_preparation != interface_conservee:
		interface_preparation.fermer()
	if interface_chauffe != null and interface_chauffe != interface_conservee:
		interface_chauffe.fermer()
	if interface_martelage != null and interface_martelage != interface_conservee:
		interface_martelage.fermer()
	if interface_fonte != null and interface_fonte != interface_conservee:
		interface_fonte.fermer()
	if interface_moulage != null and interface_moulage != interface_conservee:
		interface_moulage.fermer()
	if interface_assemblage != null and interface_assemblage != interface_conservee:
		interface_assemblage.fermer()
	if interface_coffre_reserve != null and interface_coffre_reserve != interface_conservee:
		interface_coffre_reserve.fermer()

func _verifier_configuration() -> void:
	_verifier_zone(zone_chauffe, "chemin_zone_chauffe")
	_verifier_zone(zone_demandes, "chemin_zone_demandes")
	_verifier_zone(zone_martelage, "chemin_zone_martelage")
	_verifier_zone(zone_fonte, "chemin_zone_fonte")
	_verifier_zone(zone_moulage, "chemin_zone_moulage")
	_verifier_zone(zone_assemblage, "chemin_zone_assemblage")
	_verifier_zone(zone_reserve, "chemin_zone_reserve")
	if interface_commande == null or interface_preparation == null or interface_chauffe == null or interface_martelage == null or interface_fonte == null or interface_moulage == null or interface_assemblage == null or interface_coffre_reserve == null:
		push_error("Une ou plusieurs interfaces de forge sont introuvables. Verifie les chemins exportes du GestionnaireForge.")
	if not InputMap.has_action(action_interagir):
		push_error("L'action d'entree '%s' utilisee par la forge n'existe pas." % String(action_interagir))
	var commandes: Array[DonneesCommandeForge] = obtenir_commandes_disponibles()
	if commandes.is_empty():
		push_error("Le GestionnaireForge ne possede aucune commande.")
	for index: int in commandes.size():
		var commande: DonneesCommandeForge = commandes[index]
		if commande == null:
			push_error("La commande %d du GestionnaireForge est manquante." % (index + 1))
		elif not commande.est_valide():
			push_error("La commande %s est invalide : %s" % [commande.nom, " ".join(commande.obtenir_erreurs())])

func _verifier_zone(zone: Area2D, nom_chemin: String) -> void:
	if zone == null:
		push_error("Zone de forge introuvable : %s." % nom_chemin)
		return
	var formes: Array[Node] = zone.find_children("*", "CollisionShape2D", true, false)
	for forme: Node in formes:
		var collision: CollisionShape2D = forme as CollisionShape2D
		if collision != null and collision.shape != null and not collision.disabled:
			return
	push_error("La zone %s ne possede aucune CollisionShape2D active." % nom_chemin)
