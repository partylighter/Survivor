extends Node
class_name ControleurParcoursSelection

@export var gestionnaire_selection: GestionnaireSelection
@export var gestionnaire_zones: GestionnaireZones
@export var gestionnaire_ennemis: GestionnaireEnnemis
@export var gestionnaire_esprits: GestionnaireEspritsAspirant
@export var mauvais_esprit: MauvaisEspritSelection
@export var joueur: Node2D
@export var aspirant_a: Node2D
@export var aspirant_b: Node2D
@export var zone_presentation: ZoneDefinition
@export var zone_premiere_poursuite: ZoneDefinition
@export var zone_debut_traque: ZoneDefinition
@export var scene_fragment_premiere_poursuite: PackedScene
@export var depart_mauvais_esprit: Marker2D
@export var cible_premiere_fuite: Marker2D
@export var cible_debut_traque: Marker2D
@export var spawn_fragment_1: Marker2D
@export var spawn_fragment_2: Marker2D

var fragments_poursuite_actifs: Array[Node2D] = []
var destination_traque_atteinte: bool = false
var premiere_poursuite_demarree: bool = false
var configuration_valide: bool = false

func _ready() -> void:
	configuration_valide = _verifier_configuration()
	if not configuration_valide:
		return
	gestionnaire_zones.zone_changee.connect(_quand_zone_changee)
	gestionnaire_ennemis.ennemi_tue.connect(_quand_ennemi_tue)
	mauvais_esprit.destination_atteinte.connect(_quand_destination_atteinte)
	gestionnaire_selection.selection_demarre.connect(_quand_selection_demarre)

func _quand_selection_demarre() -> void:
	gestionnaire_esprits.initialiser(joueur)
	mauvais_esprit.global_position = depart_mauvais_esprit.global_position
	mauvais_esprit.arreter()
	fragments_poursuite_actifs.clear()
	destination_traque_atteinte = false
	premiere_poursuite_demarree = false
	if gestionnaire_selection.donnees_selection != null:
		gestionnaire_selection.donnees_selection.esprits_initiaux = gestionnaire_esprits.obtenir_nombre_esprits()
		gestionnaire_selection.donnees_selection.esprits_perdus = 0

func _quand_zone_changee(_ancienne: ZoneDefinition, nouvelle: ZoneDefinition) -> void:
	if nouvelle != zone_premiere_poursuite:
		return
	if gestionnaire_selection.obtenir_etape_actuelle() != GestionnaireSelection.Etape.PRESENTATION:
		return
	_demarrer_premiere_poursuite()

func _demarrer_premiere_poursuite() -> void:
	if premiere_poursuite_demarree:
		return
	if not gestionnaire_selection.passer_etape(GestionnaireSelection.Etape.PREMIERE_POURSUITE):
		return
	premiere_poursuite_demarree = true
	mauvais_esprit.fuir_vers(cible_premiere_fuite.global_position)
	_ajouter_fragment(spawn_fragment_1.global_position)
	_ajouter_fragment(spawn_fragment_2.global_position)
	if fragments_poursuite_actifs.size() != 2:
		push_error("ControleurParcoursSelection: les deux fragments n'ont pas pu etre crees.")

func _ajouter_fragment(position_spawn: Vector2) -> void:
	var fragment: Node2D = gestionnaire_ennemis.spawn_scene_directe(scene_fragment_premiere_poursuite, position_spawn)
	if fragment != null:
		fragments_poursuite_actifs.append(fragment)

func _quand_ennemi_tue(ennemi: Node2D) -> void:
	var index_fragment: int = fragments_poursuite_actifs.find(ennemi)
	if index_fragment < 0:
		return
	fragments_poursuite_actifs.remove_at(index_fragment)
	if gestionnaire_selection.donnees_selection != null:
		gestionnaire_selection.donnees_selection.enregistrer_fragment_elimine()
		print("[Selection] Fragment elimine ", gestionnaire_selection.donnees_selection.fragments_elimines, "/2")
	if fragments_poursuite_actifs.is_empty():
		destination_traque_atteinte = false
		mauvais_esprit.fuir_vers(cible_debut_traque.global_position)

func _quand_destination_atteinte() -> void:
	if gestionnaire_selection.obtenir_etape_actuelle() != GestionnaireSelection.Etape.PREMIERE_POURSUITE:
		return
	if not fragments_poursuite_actifs.is_empty():
		return
	destination_traque_atteinte = true
	_tenter_passer_traque()

func _tenter_passer_traque() -> void:
	if not destination_traque_atteinte or not fragments_poursuite_actifs.is_empty():
		return
	if gestionnaire_selection.obtenir_etape_actuelle() != GestionnaireSelection.Etape.PREMIERE_POURSUITE:
		return
	gestionnaire_selection.passer_etape(GestionnaireSelection.Etape.TRAQUE)

func _verifier_configuration() -> bool:
	var valide: bool = true
	if gestionnaire_selection == null:
		push_error("ControleurParcoursSelection: GestionnaireSelection absent.")
		valide = false
	if gestionnaire_zones == null:
		push_error("ControleurParcoursSelection: GestionnaireZones absent.")
		valide = false
	if gestionnaire_ennemis == null:
		push_error("ControleurParcoursSelection: GestionnaireEnnemis absent.")
		valide = false
	if gestionnaire_esprits == null:
		push_error("ControleurParcoursSelection: GestionnaireEspritsAspirant absent.")
		valide = false
	if mauvais_esprit == null:
		push_error("ControleurParcoursSelection: MauvaisEspritSelection absent.")
		valide = false
	if joueur == null:
		push_error("ControleurParcoursSelection: Player absent.")
		valide = false
	if aspirant_a == null or aspirant_b == null:
		push_error("ControleurParcoursSelection: les deux aspirants sont requis.")
		valide = false
	if zone_presentation == null or zone_premiere_poursuite == null or zone_debut_traque == null:
		push_error("ControleurParcoursSelection: les trois ZoneDefinition sont requises.")
		valide = false
	if scene_fragment_premiere_poursuite == null:
		push_error("ControleurParcoursSelection: scene de fragment absente.")
		valide = false
	if depart_mauvais_esprit == null or cible_premiere_fuite == null or cible_debut_traque == null:
		push_error("ControleurParcoursSelection: marqueur du mauvais esprit absent.")
		valide = false
	if spawn_fragment_1 == null or spawn_fragment_2 == null:
		push_error("ControleurParcoursSelection: marqueur de fragment absent.")
		valide = false
	return valide
