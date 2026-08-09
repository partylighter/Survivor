extends Node
class_name GestionnaireTourPuzzleGrille

signal tour_commence(numero: int)
signal tour_termine(numero: int)
signal puzzle_reinitialise

@export_group("Rythme")
@export_range(0.01, 1.0, 0.01) var duree_poussee_joueur_s: float = 0.12
@export var verrouiller_joueur_pendant_tour: bool = true

@export_group("Refs optionnelles")
@export var joueur: CharacterBody2D
@export var deplacement_grille: GestionDeplacementGrilleJoueur
@export var gestionnaire_parcours: GestionnaireParcoursGrille

var _ennemis: Array[EnnemiPuzzleGrille] = []
var _ennemis_en_mouvement: Array[EnnemiPuzzleGrille] = []
var _resolution_en_cours: bool = false
var _numero_tour: int = 0
var _ignorer_arrivee_interne: bool = false
var _process_mode_joueur_avant: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _joueur_verrouille: bool = false
var _poussee_joueur_active: bool = false
var _poussee_ennemi: EnnemiPuzzleGrille
var _poussee_cellule_depart: Vector2i = Vector2i.ZERO
var _poussee_cellule_destination: Vector2i = Vector2i.ZERO
var _poussee_position_depart: Vector2 = Vector2.ZERO
var _poussee_position_destination: Vector2 = Vector2.ZERO
var _poussee_temps_s: float = 0.0

func _ready() -> void:
	add_to_group("gestionnaire_tour_puzzle_grille")
	call_deferred("_initialiser")

func _initialiser() -> void:
	_resoudre_references()
	_actualiser_ennemis()
	if deplacement_grille != null and not deplacement_grille.cellule_atteinte.is_connected(_quand_joueur_atteint_cellule):
		deplacement_grille.cellule_atteinte.connect(_quand_joueur_atteint_cellule)
	set_physics_process(true)

func _physics_process(dt: float) -> void:
	_resoudre_references()
	if joueur == null or deplacement_grille == null or gestionnaire_parcours == null:
		return
	_actualiser_ennemis()
	var cellule_joueur: Vector2i = deplacement_grille.obtenir_cellule_actuelle()
	var temps_reel_prets: Array[EnnemiPuzzleGrille] = []
	if gestionnaire_parcours.cellule_est_sure(cellule_joueur) or deplacement_grille.est_en_transport_plateforme():
		for ennemi in _ennemis:
			if ennemi != null and is_instance_valid(ennemi) and ennemi.avancer_horloge_temps_reel(dt, cellule_joueur):
				temps_reel_prets.append(ennemi)
	if _resolution_en_cours:
		_avancer_resolution(dt)
		return
	if not joueur.can_process():
		return
	if deplacement_grille.est_en_deplacement() or deplacement_grille.est_en_transport_plateforme():
		return
	if not gestionnaire_parcours.cellule_est_sure(cellule_joueur):
		return
	if temps_reel_prets.is_empty():
		return
	for ennemi in temps_reel_prets:
		ennemi.consommer_declenchement_temps_reel()
	_demarrer_resolution(temps_reel_prets)

func reinitialiser() -> void:
	_resoudre_references()
	_actualiser_ennemis()
	if _poussee_joueur_active and joueur != null and is_instance_valid(joueur):
		joueur.global_position = _poussee_position_depart
		joueur.velocity = Vector2.ZERO
		if deplacement_grille != null and is_instance_valid(deplacement_grille):
			deplacement_grille.synchroniser_sur_grille(joueur)
	if _poussee_joueur_active and gestionnaire_parcours != null and _poussee_ennemi != null and is_instance_valid(_poussee_ennemi):
		gestionnaire_parcours.liberer_reservations_occupant(_poussee_ennemi)
	_poussee_joueur_active = false
	_poussee_ennemi = null
	_poussee_temps_s = 0.0
	_ignorer_arrivee_interne = false
	_ennemis_en_mouvement.clear()
	for ennemi in _ennemis:
		if ennemi != null and is_instance_valid(ennemi):
			ennemi.preparer_reinitialisation()
	for ennemi in _ennemis:
		if ennemi != null and is_instance_valid(ennemi):
			ennemi.restaurer_initial()
	_resolution_en_cours = false
	_deverrouiller_joueur()
	puzzle_reinitialise.emit()

func est_en_resolution() -> bool:
	return _resolution_en_cours

func _quand_joueur_atteint_cellule(cellule: Vector2i) -> void:
	if _ignorer_arrivee_interne or _resolution_en_cours:
		return
	_resoudre_references()
	if gestionnaire_parcours == null or not gestionnaire_parcours.cellule_est_sure(cellule):
		return
	_actualiser_ennemis()
	var a_activer: Array[EnnemiPuzzleGrille] = []
	for ennemi in _ennemis:
		if ennemi != null and is_instance_valid(ennemi) and ennemi.notifier_deplacement_joueur(cellule):
			a_activer.append(ennemi)
	if not a_activer.is_empty():
		_demarrer_resolution(a_activer)

func _demarrer_resolution(ennemis_a_activer: Array[EnnemiPuzzleGrille]) -> void:
	if _resolution_en_cours or ennemis_a_activer.is_empty():
		return
	_resoudre_references()
	if joueur == null or deplacement_grille == null or gestionnaire_parcours == null:
		return
	var eligibles: Array[EnnemiPuzzleGrille] = []
	for ennemi in ennemis_a_activer:
		if ennemi != null and is_instance_valid(ennemi) and ennemi.est_actif_pour_tour():
			eligibles.append(ennemi)
	if eligibles.is_empty():
		return
	eligibles.sort_custom(Callable(self, "_ennemi_avant"))
	_resolution_en_cours = true
	_numero_tour += 1
	tour_commence.emit(_numero_tour)
	_verrouiller_joueur()
	_resoudre_intentions(eligibles)
	if _ennemis_en_mouvement.is_empty() and not _poussee_joueur_active:
		_terminer_resolution()

func _resoudre_intentions(ennemis_a_activer: Array[EnnemiPuzzleGrille]) -> void:
	var cellule_joueur: Vector2i = deplacement_grille.obtenir_cellule_actuelle()
	var intentions: Array[Dictionary] = []
	var compte_destinations: Dictionary = {}
	for ennemi in ennemis_a_activer:
		var direction: Vector2i = ennemi.obtenir_direction_intention()
		if direction == Vector2i.ZERO:
			ennemi.resoudre_etape_sans_deplacement(true)
			continue
		if abs(direction.x) + abs(direction.y) != 1:
			ennemi.resoudre_etape_sans_deplacement(false)
			continue
		var destination: Vector2i = ennemi.cellule + direction
		intentions.append({"ennemi": ennemi, "direction": direction, "destination": destination})
		compte_destinations[destination] = int(compte_destinations.get(destination, 0)) + 1
	var contacts_joueur: Array[Dictionary] = []
	for intention in intentions:
		var ennemi := intention["ennemi"] as EnnemiPuzzleGrille
		var destination: Vector2i = intention["destination"]
		if ennemi == null or not is_instance_valid(ennemi):
			continue
		if int(compte_destinations.get(destination, 0)) > 1:
			ennemi.resoudre_etape_sans_deplacement(false)
			continue
		if destination == cellule_joueur:
			contacts_joueur.append(intention)
			continue
		if not ennemi.peut_entrer_destination(joueur, destination):
			ennemi.resoudre_etape_sans_deplacement(false)
			continue
		if ennemi.demarrer_deplacement_tour(destination):
			_ennemis_en_mouvement.append(ennemi)
		else:
			ennemi.resoudre_etape_sans_deplacement(false)
	_resoudre_contacts_joueur(contacts_joueur, compte_destinations)

func _resoudre_contacts_joueur(contacts: Array[Dictionary], compte_destinations: Dictionary) -> void:
	if contacts.is_empty():
		return
	if contacts.size() > 1:
		for intention in contacts:
			var ennemi_contact := intention["ennemi"] as EnnemiPuzzleGrille
			if ennemi_contact != null and is_instance_valid(ennemi_contact):
				ennemi_contact.resoudre_etape_sans_deplacement(false)
		return
	var intention: Dictionary = contacts[0]
	var ennemi := intention["ennemi"] as EnnemiPuzzleGrille
	var direction: Vector2i = intention["direction"]
	if ennemi == null or not is_instance_valid(ennemi):
		return
	if ennemi.inflige_degats:
		ennemi.appliquer_degats_joueur(joueur)
	if not ennemi.pousse_joueur:
		ennemi.resoudre_etape_sans_deplacement(false)
		return
	var destination_joueur: Vector2i = deplacement_grille.obtenir_cellule_actuelle() + direction
	if int(compte_destinations.get(destination_joueur, 0)) > 0:
		ennemi.resoudre_etape_sans_deplacement(false)
		return
	if not _demarrer_poussee_joueur(ennemi, direction, destination_joueur):
		ennemi.resoudre_etape_sans_deplacement(false)

func _demarrer_poussee_joueur(ennemi: EnnemiPuzzleGrille, direction: Vector2i, destination: Vector2i) -> bool:
	if _poussee_joueur_active or joueur == null or deplacement_grille == null or gestionnaire_parcours == null:
		return false
	if abs(direction.x) + abs(direction.y) != 1:
		return false
	if not deplacement_grille.cellule_est_accessible(joueur, destination, false):
		return false
	var reservation: Array[Vector2i] = [destination]
	if not gestionnaire_parcours.reserver_cellules_occupant(ennemi, reservation):
		return false
	_poussee_ennemi = ennemi
	_poussee_cellule_depart = deplacement_grille.obtenir_cellule_actuelle()
	_poussee_cellule_destination = destination
	_poussee_position_depart = joueur.global_position
	_poussee_position_destination = deplacement_grille.cellule_vers_monde(destination)
	_poussee_temps_s = 0.0
	_poussee_joueur_active = true
	return true

func _avancer_resolution(dt: float) -> void:
	if _poussee_joueur_active:
		_avancer_poussee_joueur(dt)
	for index in range(_ennemis_en_mouvement.size() - 1, -1, -1):
		var ennemi: EnnemiPuzzleGrille = _ennemis_en_mouvement[index]
		if ennemi == null or not is_instance_valid(ennemi):
			_ennemis_en_mouvement.remove_at(index)
			continue
		if ennemi.est_en_deplacement_occupant():
			ennemi.avancer_deplacement_tour(dt)
		if not ennemi.est_en_deplacement_occupant():
			_ennemis_en_mouvement.remove_at(index)
	if not _poussee_joueur_active and _ennemis_en_mouvement.is_empty():
		_terminer_resolution()

func _avancer_poussee_joueur(dt: float) -> void:
	if not _poussee_joueur_active:
		return
	if joueur == null or not is_instance_valid(joueur):
		_annuler_poussee_joueur()
		return
	var duree: float = maxf(duree_poussee_joueur_s, 0.01)
	var ancienne_position: Vector2 = joueur.global_position
	_poussee_temps_s = minf(_poussee_temps_s + dt, duree)
	var progression: float = _poussee_temps_s / duree
	var progression_douce: float = progression * progression * (3.0 - 2.0 * progression)
	joueur.global_position = _poussee_position_depart.lerp(_poussee_position_destination, progression_douce)
	joueur.velocity = (joueur.global_position - ancienne_position) / maxf(dt, 0.0001)
	if _poussee_temps_s < duree:
		return
	joueur.global_position = _poussee_position_destination
	joueur.velocity = Vector2.ZERO
	var ennemi: EnnemiPuzzleGrille = _poussee_ennemi
	if gestionnaire_parcours != null and ennemi != null and is_instance_valid(ennemi):
		gestionnaire_parcours.liberer_reservations_occupant(ennemi)
	deplacement_grille.synchroniser_sur_grille(joueur)
	_ignorer_arrivee_interne = true
	deplacement_grille.cellule_atteinte.emit(_poussee_cellule_destination)
	_ignorer_arrivee_interne = false
	_poussee_joueur_active = false
	_poussee_ennemi = null
	if ennemi == null or not is_instance_valid(ennemi) or not ennemi.est_actif_pour_tour():
		return
	if not ennemi.peut_entrer_destination(joueur, _poussee_cellule_depart):
		ennemi.resoudre_etape_sans_deplacement(false)
		return
	if ennemi.demarrer_deplacement_tour(_poussee_cellule_depart):
		_ennemis_en_mouvement.append(ennemi)
	else:
		ennemi.resoudre_etape_sans_deplacement(false)

func _annuler_poussee_joueur() -> void:
	if gestionnaire_parcours != null and _poussee_ennemi != null and is_instance_valid(_poussee_ennemi):
		gestionnaire_parcours.liberer_reservations_occupant(_poussee_ennemi)
	_poussee_joueur_active = false
	_poussee_ennemi = null

func _terminer_resolution() -> void:
	if not _resolution_en_cours:
		return
	_resolution_en_cours = false
	_deverrouiller_joueur()
	tour_termine.emit(_numero_tour)

func _verrouiller_joueur() -> void:
	if not verrouiller_joueur_pendant_tour or joueur == null or not is_instance_valid(joueur):
		return
	if deplacement_grille != null:
		deplacement_grille.interrompre_sans_recaler(joueur)
	_process_mode_joueur_avant = joueur.process_mode
	joueur.process_mode = Node.PROCESS_MODE_DISABLED
	_joueur_verrouille = true

func _deverrouiller_joueur() -> void:
	if not _joueur_verrouille:
		return
	if joueur != null and is_instance_valid(joueur):
		joueur.process_mode = _process_mode_joueur_avant
	_joueur_verrouille = false

func _actualiser_ennemis() -> void:
	var trouves: Array[EnnemiPuzzleGrille] = []
	for noeud in get_tree().get_nodes_in_group("ennemi_puzzle_grille"):
		var ennemi := noeud as EnnemiPuzzleGrille
		if ennemi != null and is_instance_valid(ennemi) and ennemi.gestionnaire_parcours == gestionnaire_parcours:
			trouves.append(ennemi)
	trouves.sort_custom(Callable(self, "_ennemi_avant"))
	_ennemis = trouves

func _ennemi_avant(a: EnnemiPuzzleGrille, b: EnnemiPuzzleGrille) -> bool:
	if a.ordre_resolution == b.ordre_resolution:
		return a.get_instance_id() < b.get_instance_id()
	return a.ordre_resolution < b.ordre_resolution

func _resoudre_references() -> void:
	if gestionnaire_parcours == null or not is_instance_valid(gestionnaire_parcours):
		var racine_niveau: Node = get_parent()
		if racine_niveau != null:
			gestionnaire_parcours = racine_niveau.get_node_or_null("GestionnaireParcoursGrille") as GestionnaireParcoursGrille
		if gestionnaire_parcours == null:
			gestionnaire_parcours = get_tree().get_first_node_in_group("gestionnaire_parcours_grille") as GestionnaireParcoursGrille
	if joueur == null or not is_instance_valid(joueur):
		if gestionnaire_parcours != null:
			joueur = gestionnaire_parcours.joueur
		if joueur == null:
			joueur = get_tree().get_first_node_in_group("joueur_principal") as CharacterBody2D
	if deplacement_grille == null or not is_instance_valid(deplacement_grille):
		if gestionnaire_parcours != null:
			deplacement_grille = gestionnaire_parcours.deplacement_grille
		if deplacement_grille == null and joueur != null:
			deplacement_grille = joueur.get_node_or_null("GestionDeplacementGrilleJoueur") as GestionDeplacementGrilleJoueur
		if deplacement_grille == null:
			deplacement_grille = get_tree().get_first_node_in_group("deplacement_grille_joueur") as GestionDeplacementGrilleJoueur

func _exit_tree() -> void:
	if _resolution_en_cours:
		reinitialiser()
	_deverrouiller_joueur()
