extends Node
class_name GestionDeplacementGrilleJoueur

signal cellule_quittee(cellule: Vector2i)
signal cellule_cible_changee(cellule: Vector2i)
signal cellule_atteinte(cellule: Vector2i)
signal deplacement_refuse(cellule: Vector2i)
signal dash_grille_demarre(depart: Vector2i, destination: Vector2i)
signal dash_grille_termine(destination: Vector2i)

enum CourbeInterpolation {
	LINEAIRE,
	DOUCE
}

@export_group("Grille")
@export_range(0.03, 0.5, 0.01) var duree_pas_s: float = 0.12
@export var diagonales_autorisees: bool = true
@export var maintien_touche_actif: bool = true
@export_range(0.0, 0.5, 0.01) var delai_repetition_initial_s: float = 0.10
@export_range(0.0, 0.5, 0.01) var intervalle_repetition_s: float = 0.02
@export var buffer_entree_actif: bool = true
@export_range(0.0, 0.5, 0.01) var duree_buffer_entree_s: float = 0.18

@export_group("Vitesse")
@export var vitesse_reference_px_s: float = 300.0
@export var duree_pas_min_s: float = 0.06
@export var duree_pas_max_s: float = 0.18
@export var courbe_interpolation: CourbeInterpolation = CourbeInterpolation.DOUCE

@export_group("Collisions")
@export var bloquer_diagonale_coin: bool = true

@export_group("Dash grille")
@export_range(1, 8, 1) var distance_dash_cellules: int = 3
@export_range(0.01, 0.3, 0.01) var duree_dash_par_cellule_s: float = 0.05

@export_group("Recul grille")
@export_range(0.01, 0.5, 0.01) var duree_recul_cellule_s: float = 0.10

var cellule_actuelle: Vector2i = Vector2i.ZERO
var cellule_cible: Vector2i = Vector2i.ZERO
var position_depart: Vector2 = Vector2.ZERO
var position_cible: Vector2 = Vector2.ZERO
var _duree_deplacement_s: float = 0.0
var _temps_deplacement_s: float = 0.0
var _en_deplacement: bool = false
var _en_dash: bool = false
var _deplacement_force: bool = false
var _synchronise: bool = false
var _direction_derniere: Vector2i = Vector2i.RIGHT
var _direction_maintenue_precedente: Vector2i = Vector2i.ZERO
var _temps_maintien_s: float = 0.0
var _temps_depuis_repetition_s: float = 0.0
var _direction_buffer: Vector2i = Vector2i.ZERO
var _temps_buffer_restant_s: float = 0.0
var _dash_en_preparation: bool = false
var _preparation_dash_en_attente: bool = false
var _direction_dash_preparee: Vector2i = Vector2i.ZERO
var _direction_dash_a_relacher: Vector2i = Vector2i.ZERO
var _chemin_dash_debug: Array[Vector2i] = []
var _cellule_refusee_debug: Vector2i = Vector2i.ZERO
var _cellule_refusee_presente: bool = false
var _gestionnaire_grille: GestionnaireGrilleCombat
var _gestionnaire_parcours: Node
var _occupant_pousse_en_cours: Node
var _transport_plateforme_source: Node
var _transport_plateforme_actif: bool = false

func _ready() -> void:
	add_to_group("deplacement_grille_joueur")
	_resoudre_gestionnaire_grille()
	_resoudre_gestionnaire_parcours()

func traiter(joueur: CharacterBody2D, stats: StatsJoueur, dt: float) -> void:
	_resoudre_gestionnaire_grille()
	_resoudre_gestionnaire_parcours()
	if _gestionnaire_grille == null:
		joueur.velocity = Vector2.ZERO
		return
	if not _synchronise:
		synchroniser_sur_grille(joueur)
	_mettre_a_jour_recharge_dash(joueur, stats, dt)
	if _transport_plateforme_actif:
		joueur.velocity = Vector2.ZERO
		return
	_mettre_a_jour_temps_buffers(dt)
	_mettre_a_jour_direction_dash_a_relacher()
	var direction_maintenue: Vector2i = _obtenir_direction_entree()
	var direction_dash_maintenue: Vector2i = _obtenir_direction_entree(true)
	var direction_juste_appuyee: Vector2i = _obtenir_direction_juste_appuyee(direction_maintenue)
	if _en_deplacement:
		var dash_bloque_entrees: bool = false
		if not _en_dash and Input.is_action_just_pressed("dash") and _commencer_attente_preparation_dash(joueur, direction_dash_maintenue):
			dash_bloque_entrees = true
		elif _preparation_dash_en_attente:
			dash_bloque_entrees = true
			if Input.is_action_just_released("dash") or not Input.is_action_pressed("dash"):
				_annuler_preparation_dash()
			else:
				_mettre_a_jour_direction_dash_preparee(direction_dash_maintenue)
		if not dash_bloque_entrees:
			_mettre_a_jour_maintien(direction_maintenue, dt)
			if direction_juste_appuyee != Vector2i.ZERO:
				_memoriser_direction_buffer(direction_juste_appuyee)
		_avancer_deplacement(joueur, dt)
		if not _en_deplacement:
			_consomme_entree_apres_arrivee(joueur, stats, direction_maintenue)
		return
	joueur.velocity = Vector2.ZERO
	if _dash_en_preparation:
		_traiter_preparation_dash(joueur, stats, direction_dash_maintenue)
		return
	if Input.is_action_just_pressed("dash") and _commencer_preparation_dash(joueur, direction_dash_maintenue):
		return
	_mettre_a_jour_maintien(direction_maintenue, dt)
	if direction_juste_appuyee != Vector2i.ZERO:
		_essayer_demarrer_pas(joueur, stats, direction_juste_appuyee)
		return
	if _repetition_maintien_prete(direction_maintenue):
		_temps_depuis_repetition_s = 0.0
		_essayer_demarrer_pas(joueur, stats, direction_maintenue)

func synchroniser_sur_grille(joueur: CharacterBody2D) -> void:
	if _transport_plateforme_actif:
		_interrompre_transport_source(joueur)
	_resoudre_gestionnaire_grille()
	if _gestionnaire_grille == null:
		_synchronise = false
		return
	cellule_actuelle = monde_vers_cellule(joueur.global_position)
	cellule_cible = cellule_actuelle
	position_depart = cellule_vers_monde(cellule_actuelle)
	position_cible = position_depart
	joueur.global_position = position_depart
	joueur.velocity = Vector2.ZERO
	_reinitialiser_etat_transitoire(joueur)
	_synchronise = true

func interrompre_et_recaler(joueur: CharacterBody2D) -> void:
	if _transport_plateforme_actif:
		_interrompre_transport_source(joueur)
	if not _synchronise:
		synchroniser_sur_grille(joueur)
		return
	joueur.global_position = cellule_vers_monde(cellule_actuelle)
	joueur.velocity = Vector2.ZERO
	cellule_cible = cellule_actuelle
	position_depart = joueur.global_position
	position_cible = joueur.global_position
	_reinitialiser_etat_transitoire(joueur)
	cellule_cible_changee.emit(cellule_cible)

func interrompre_sans_recaler(joueur: CharacterBody2D) -> void:
	if _transport_plateforme_actif:
		_interrompre_transport_source(joueur)
	if not _synchronise:
		synchroniser_sur_grille(joueur)
		return
	cellule_actuelle = monde_vers_cellule(joueur.global_position)
	cellule_cible = cellule_actuelle
	position_depart = joueur.global_position
	position_cible = joueur.global_position
	joueur.velocity = Vector2.ZERO
	_reinitialiser_etat_transitoire(joueur)
	_synchronise = true
	cellule_cible_changee.emit(cellule_cible)

func obtenir_cellule_actuelle() -> Vector2i:
	return cellule_actuelle

func obtenir_cellule_cible() -> Vector2i:
	return cellule_cible

func est_en_deplacement() -> bool:
	return _en_deplacement

func est_en_dash() -> bool:
	return _en_dash

func est_en_transport_plateforme() -> bool:
	return _transport_plateforme_actif

func commencer_transport_plateforme(joueur: CharacterBody2D, source: Node, destination: Vector2i) -> bool:
	if source == null or not is_instance_valid(source) or _transport_plateforme_actif or _en_deplacement:
		return false
	if _dash_en_preparation or _preparation_dash_en_attente:
		return false
	if not _synchronise:
		synchroniser_sur_grille(joueur)
	if not _synchronise:
		return false
	var direction: Vector2i = destination - cellule_actuelle
	if abs(direction.x) + abs(direction.y) != 1:
		return false
	_transport_plateforme_source = source
	_transport_plateforme_actif = true
	_direction_derniere = direction
	cellule_cible = destination
	position_depart = joueur.global_position
	position_cible = cellule_vers_monde(destination)
	_effacer_direction_buffer()
	_reinitialiser_maintien()
	_dash_en_preparation = false
	_preparation_dash_en_attente = false
	_direction_dash_preparee = Vector2i.ZERO
	joueur.velocity = Vector2.ZERO
	cellule_cible_changee.emit(cellule_cible)
	cellule_quittee.emit(cellule_actuelle)
	return true

func terminer_transport_plateforme(joueur: CharacterBody2D, source: Node, destination: Vector2i, emettre_arrivee: bool = true) -> bool:
	if not _transport_plateforme_actif or source != _transport_plateforme_source:
		return false
	joueur.global_position = cellule_vers_monde(destination)
	joueur.velocity = Vector2.ZERO
	cellule_actuelle = destination
	cellule_cible = destination
	position_depart = joueur.global_position
	position_cible = joueur.global_position
	_transport_plateforme_actif = false
	_transport_plateforme_source = null
	_effacer_direction_buffer()
	_reinitialiser_maintien()
	_dash_en_preparation = false
	_preparation_dash_en_attente = false
	_direction_dash_preparee = Vector2i.ZERO
	_direction_dash_a_relacher = Vector2i.ZERO
	_direction_dash_a_relacher = _obtenir_direction_entree(true)
	if emettre_arrivee:
		cellule_atteinte.emit(cellule_actuelle)
	return true

func annuler_transport_plateforme(joueur: CharacterBody2D, source: Node, cellule_retour: Vector2i) -> bool:
	if not _transport_plateforme_actif or source != _transport_plateforme_source:
		return false
	_transport_plateforme_actif = false
	_transport_plateforme_source = null
	cellule_actuelle = cellule_retour
	cellule_cible = cellule_retour
	joueur.global_position = cellule_vers_monde(cellule_retour)
	joueur.velocity = Vector2.ZERO
	position_depart = joueur.global_position
	position_cible = joueur.global_position
	_effacer_direction_buffer()
	_reinitialiser_maintien()
	_dash_en_preparation = false
	_preparation_dash_en_attente = false
	_direction_dash_preparee = Vector2i.ZERO
	_direction_dash_a_relacher = Vector2i.ZERO
	_direction_dash_a_relacher = _obtenir_direction_entree(true)
	cellule_cible_changee.emit(cellule_cible)
	return true

func cellule_vers_monde(cellule: Vector2i) -> Vector2:
	_resoudre_gestionnaire_grille()
	return _gestionnaire_grille.cellule_vers_monde(cellule) if _gestionnaire_grille != null else Vector2.ZERO

func monde_vers_cellule(position_monde: Vector2) -> Vector2i:
	_resoudre_gestionnaire_grille()
	return _gestionnaire_grille.monde_vers_cellule(position_monde) if _gestionnaire_grille != null else Vector2i.ZERO

func obtenir_gestionnaire_grille() -> GestionnaireGrilleCombat:
	_resoudre_gestionnaire_grille()
	return _gestionnaire_grille

func calculer_duree_pas(stats: StatsJoueur) -> float:
	var vitesse: float = vitesse_reference_px_s
	if stats != null:
		vitesse = maxf(stats.get_vitesse_effective(), 1.0)
	var reference: float = maxf(vitesse_reference_px_s, 1.0)
	var duree: float = duree_pas_s * reference / vitesse
	return clampf(duree, minf(duree_pas_min_s, duree_pas_max_s), maxf(duree_pas_min_s, duree_pas_max_s))

func cellule_est_accessible(joueur: CharacterBody2D, cellule: Vector2i, verifier_coins: bool = true) -> bool:
	if not _cellule_logiquement_disponible_pour_joueur(cellule):
		return false
	if not _cellule_est_accessible_simple(joueur, cellule):
		return false
	var direction: Vector2i = cellule - cellule_actuelle
	if verifier_coins and bloquer_diagonale_coin and abs(direction.x) == 1 and abs(direction.y) == 1:
		var cellule_horizontale := cellule_actuelle + Vector2i(direction.x, 0)
		var cellule_verticale := cellule_actuelle + Vector2i(0, direction.y)
		if not _cellule_logiquement_disponible_pour_joueur(cellule_horizontale) or not _cellule_logiquement_disponible_pour_joueur(cellule_verticale):
			return false
		if not _cellule_est_accessible_simple(joueur, cellule_horizontale):
			return false
		if not _cellule_est_accessible_simple(joueur, cellule_verticale):
			return false
	return true

func appliquer_recul_cellules(joueur: CharacterBody2D, direction: Vector2i, distance_cellules: int = 1) -> bool:
	var direction_recul := Vector2i(clampi(direction.x, -1, 1), clampi(direction.y, -1, 1))
	if direction_recul == Vector2i.ZERO or (direction_recul.x != 0 and direction_recul.y != 0) or distance_cellules <= 0:
		return false
	if not _synchronise:
		synchroniser_sur_grille(joueur)
	if not _synchronise:
		return false
	if _en_deplacement:
		interrompre_sans_recaler(joueur)
	var destination: Vector2i = cellule_actuelle
	var position_segment_depart: Vector2 = joueur.global_position
	var distance_reelle: int = 0
	for _index in range(distance_cellules):
		var prochaine_cellule: Vector2i = destination + direction_recul
		var position_prochaine: Vector2 = cellule_vers_monde(prochaine_cellule)
		if not _segment_est_accessible(joueur, position_segment_depart, position_prochaine):
			break
		destination = prochaine_cellule
		position_segment_depart = position_prochaine
		distance_reelle += 1
	if distance_reelle <= 0:
		return false
	_direction_derniere = direction_recul
	_deplacement_force = true
	_demarrer_deplacement(joueur, destination, maxf(duree_recul_cellule_s, 0.01) * float(distance_reelle), false)
	return true

func obtenir_direction_buffer() -> Vector2i:
	return _direction_buffer if _temps_buffer_restant_s > 0.0 else Vector2i.ZERO

func obtenir_chemin_dash_debug() -> Array[Vector2i]:
	return _chemin_dash_debug.duplicate()

func obtenir_cellule_refusee_debug() -> Vector2i:
	return _cellule_refusee_debug

func cellule_refusee_debug_presente() -> bool:
	return _cellule_refusee_presente

func _essayer_demarrer_pas(joueur: CharacterBody2D, stats: StatsJoueur, direction: Vector2i) -> bool:
	var direction_valide: Vector2i = _limiter_direction(direction)
	if direction_valide == Vector2i.ZERO:
		return false
	var destination: Vector2i = cellule_actuelle + direction_valide
	_resoudre_gestionnaire_parcours()
	var occupant: Node = _obtenir_occupant_parcours(destination)
	if occupant != null and Input.is_action_pressed("interagir") and occupant.has_method("est_deplacable_manuellement_par_joueur") and bool(occupant.call("est_deplacable_manuellement_par_joueur")):
		if occupant.has_method("demarrer_deplacement_manuel_par_joueur") and bool(occupant.call("demarrer_deplacement_manuel_par_joueur", joueur, direction_valide)):
			_direction_derniere = direction_valide
			_effacer_direction_buffer()
			_reinitialiser_maintien()
		else:
			_signaler_refus(destination)
		return true
	if occupant != null and not _occupant_autorise_joueur(occupant):
		if _essayer_pousser_occupant(joueur, stats, occupant, direction_valide):
			return true
		_signaler_refus(destination)
		return false
	if not _cellule_logiquement_disponible_pour_joueur(destination):
		_signaler_refus(destination)
		return false
	if not cellule_est_accessible(joueur, destination):
		_signaler_refus(destination)
		return false
	_direction_derniere = direction_valide
	var multiplicateur_diagonal: float = sqrt(2.0) if abs(direction_valide.x) == 1 and abs(direction_valide.y) == 1 else 1.0
	_demarrer_deplacement(joueur, destination, calculer_duree_pas(stats) * multiplicateur_diagonal, false)
	return true

func _essayer_pousser_occupant(joueur: CharacterBody2D, stats: StatsJoueur, occupant: Node, direction: Vector2i) -> bool:
	if occupant == null or abs(direction.x) + abs(direction.y) != 1:
		return false
	if not occupant.has_method("peut_etre_pousse_par_joueur") or not bool(occupant.call("peut_etre_pousse_par_joueur", joueur, direction)):
		return false
	var destination_joueur: Vector2i = cellule_actuelle + direction
	var rids_a_ignorer: Array = []
	if occupant.has_method("obtenir_rids_collision_pour_joueur"):
		var valeur_rids: Variant = occupant.call("obtenir_rids_collision_pour_joueur")
		if valeur_rids is Array:
			rids_a_ignorer = valeur_rids
	if not _segment_est_accessible(joueur, joueur.global_position, cellule_vers_monde(destination_joueur), rids_a_ignorer):
		return false
	var duree: float = calculer_duree_pas(stats)
	if not occupant.has_method("demarrer_poussee_joueur") or not bool(occupant.call("demarrer_poussee_joueur", joueur, direction, duree)):
		return false
	_occupant_pousse_en_cours = occupant
	_direction_derniere = direction
	_demarrer_deplacement(joueur, destination_joueur, duree, false)
	return true

func _essayer_demarrer_dash(joueur: CharacterBody2D, _stats: StatsJoueur, direction_entree: Vector2i) -> bool:
	if not _dash_peut_etre_prepare(joueur):
		return false
	var direction: Vector2i = _limiter_direction_dash(direction_entree)
	if direction == Vector2i.ZERO:
		return false
	var controleur: GestionDeplacementJoueur = _obtenir_controleur(joueur)
	var chemin: Array[Vector2i] = []
	var cellule_depart: Vector2i = cellule_actuelle
	var cellule_test: Vector2i = cellule_depart
	for _index in range(maxi(distance_dash_cellules, 1)):
		var prochaine_cellule: Vector2i = cellule_test + direction
		if not _cellule_dash_est_accessible(joueur, cellule_test, prochaine_cellule):
			_signaler_refus(prochaine_cellule)
			break
		chemin.append(prochaine_cellule)
		cellule_test = prochaine_cellule
	if chemin.is_empty():
		return false
	_direction_derniere = direction
	_chemin_dash_debug.clear()
	_chemin_dash_debug.append(cellule_depart)
	_chemin_dash_debug.append_array(chemin)
	if not joueur.dash_infini_actif:
		joueur.dash_charges_actuelles -= 1
	joueur.dash_timer_recup_s = 0.0
	joueur.dash_direction = Vector2(direction).normalized()
	var multiplicateur_diagonal: float = sqrt(2.0) if abs(direction.x) == 1 and abs(direction.y) == 1 else 1.0
	var duree_dash: float = maxf(duree_dash_par_cellule_s, 0.01) * float(chemin.size()) * multiplicateur_diagonal
	joueur.dash_duree_s = duree_dash
	joueur.dash_t_restant_s = duree_dash
	if joueur is Player:
		var player_dash := joueur as Player
		if player_dash.soif != null and is_instance_valid(player_dash.soif) and controleur != null:
			player_dash.soif.perdre_soif(controleur.obtenir_cout_soif_dash())
	if controleur != null:
		controleur.demarrer_knockback_dash_grille()
	_demarrer_deplacement(joueur, chemin.back(), duree_dash, true)
	dash_grille_demarre.emit(cellule_depart, chemin.back())
	return true

func _dash_peut_etre_prepare(joueur: CharacterBody2D) -> bool:
	if not joueur.dash_autorise or joueur.dash_t_restant_s > 0.0:
		return false
	return joueur.dash_infini_actif or joueur.dash_charges_actuelles > 0

func _commencer_preparation_dash(joueur: CharacterBody2D, direction: Vector2i) -> bool:
	if not _dash_peut_etre_prepare(joueur):
		return false
	_dash_en_preparation = true
	_preparation_dash_en_attente = false
	_direction_dash_preparee = Vector2i.ZERO
	_mettre_a_jour_direction_dash_preparee(direction)
	_effacer_direction_buffer()
	_reinitialiser_maintien()
	return true

func _commencer_attente_preparation_dash(joueur: CharacterBody2D, direction: Vector2i) -> bool:
	if not _dash_peut_etre_prepare(joueur):
		return false
	_dash_en_preparation = false
	_preparation_dash_en_attente = true
	_direction_dash_preparee = Vector2i.ZERO
	_mettre_a_jour_direction_dash_preparee(direction)
	_effacer_direction_buffer()
	_reinitialiser_maintien()
	return true

func _mettre_a_jour_direction_dash_preparee(direction: Vector2i) -> void:
	var direction_valide: Vector2i = _limiter_direction_dash(direction)
	if direction_valide != Vector2i.ZERO:
		_direction_dash_preparee = direction_valide

func _traiter_preparation_dash(joueur: CharacterBody2D, stats: StatsJoueur, direction: Vector2i) -> void:
	_mettre_a_jour_direction_dash_preparee(direction)
	if Input.is_action_just_released("dash"):
		var direction_preparee: Vector2i = _direction_dash_preparee
		_annuler_preparation_dash()
		if direction_preparee != Vector2i.ZERO:
			_essayer_demarrer_dash(joueur, stats, direction_preparee)
		return
	if not Input.is_action_pressed("dash"):
		_annuler_preparation_dash()

func _annuler_preparation_dash() -> void:
	_dash_en_preparation = false
	_preparation_dash_en_attente = false
	_direction_dash_preparee = Vector2i.ZERO
	_effacer_direction_buffer()
	_reinitialiser_maintien()

func _demarrer_deplacement(joueur: CharacterBody2D, destination: Vector2i, duree: float, dash: bool) -> void:
	cellule_cible = destination
	position_depart = joueur.global_position
	position_cible = cellule_vers_monde(destination)
	_duree_deplacement_s = maxf(duree, 0.001)
	_temps_deplacement_s = 0.0
	_en_deplacement = true
	_en_dash = dash
	_cellule_refusee_presente = false
	cellule_cible_changee.emit(cellule_cible)
	cellule_quittee.emit(cellule_actuelle)

func _avancer_deplacement(joueur: CharacterBody2D, dt: float) -> void:
	if _occupant_pousse_en_cours != null:
		if is_instance_valid(_occupant_pousse_en_cours) and not _occupant_pousse_en_cours.is_queued_for_deletion() and _occupant_pousse_en_cours.has_method("avancer_deplacement_coordonne"):
			_occupant_pousse_en_cours.call("avancer_deplacement_coordonne", dt)
		else:
			_occupant_pousse_en_cours = null
	var ancienne_position: Vector2 = joueur.global_position
	_temps_deplacement_s = minf(_temps_deplacement_s + dt, _duree_deplacement_s)
	var progression: float = _temps_deplacement_s / _duree_deplacement_s
	joueur.global_position = position_depart.lerp(position_cible, _appliquer_courbe_interpolation(progression))
	joueur.velocity = (joueur.global_position - ancienne_position) / maxf(dt, 0.0001)
	if _en_dash:
		joueur.dash_t_restant_s = maxf(_duree_deplacement_s - _temps_deplacement_s, 0.0)
		var controleur: GestionDeplacementJoueur = _obtenir_controleur(joueur)
		if controleur != null:
			controleur.appliquer_knockback_dash_grille(joueur, ancienne_position, joueur.global_position)
	if _temps_deplacement_s < _duree_deplacement_s:
		return
	var etait_dash: bool = _en_dash
	var etait_force: bool = _deplacement_force
	joueur.global_position = position_cible
	cellule_actuelle = cellule_cible
	_en_deplacement = false
	_en_dash = false
	_deplacement_force = false
	joueur.velocity = Vector2.ZERO
	_terminer_poussee_coordonne()
	cellule_atteinte.emit(cellule_actuelle)
	if etait_dash:
		joueur.dash_t_restant_s = 0.0
		_direction_dash_a_relacher = Vector2i(signi(roundi(joueur.dash_direction.x)), signi(roundi(joueur.dash_direction.y)))
		_direction_buffer = _filtrer_direction_dash_a_relacher(_direction_buffer)
		if _direction_buffer == Vector2i.ZERO:
			_effacer_direction_buffer()
		dash_grille_termine.emit(cellule_actuelle)
		_chemin_dash_debug.clear()
	elif not etait_force:
		_appliquer_soif_distance(joueur, position_depart.distance_to(position_cible))

func _terminer_poussee_coordonne() -> void:
	if _occupant_pousse_en_cours == null:
		return
	if is_instance_valid(_occupant_pousse_en_cours) and not _occupant_pousse_en_cours.is_queued_for_deletion():
		if _occupant_pousse_en_cours.has_method("est_en_deplacement_occupant") and bool(_occupant_pousse_en_cours.call("est_en_deplacement_occupant")) and _occupant_pousse_en_cours.has_method("terminer_deplacement_immediatement"):
			_occupant_pousse_en_cours.call("terminer_deplacement_immediatement")
	_occupant_pousse_en_cours = null

func _consomme_entree_apres_arrivee(joueur: CharacterBody2D, stats: StatsJoueur, direction_maintenue: Vector2i) -> void:
	direction_maintenue = _filtrer_direction_dash_a_relacher(direction_maintenue)
	if _preparation_dash_en_attente:
		if Input.is_action_pressed("dash") and _dash_peut_etre_prepare(joueur):
			_dash_en_preparation = true
			_preparation_dash_en_attente = false
			_mettre_a_jour_direction_dash_preparee(_obtenir_direction_entree(true))
			_effacer_direction_buffer()
			_reinitialiser_maintien()
			return
		_annuler_preparation_dash()
	if _direction_buffer != Vector2i.ZERO and _temps_buffer_restant_s > 0.0:
		var direction: Vector2i = _direction_buffer
		_effacer_direction_buffer()
		if _essayer_demarrer_pas(joueur, stats, direction):
			return
	if _repetition_maintien_prete(direction_maintenue):
		_temps_depuis_repetition_s = 0.0
		_essayer_demarrer_pas(joueur, stats, direction_maintenue)

func _cellule_dash_est_accessible(joueur: CharacterBody2D, depart: Vector2i, destination: Vector2i) -> bool:
	if not _cellule_logiquement_disponible_pour_joueur(destination):
		return false
	var position_depart_cellule: Vector2 = cellule_vers_monde(depart)
	if not _segment_est_accessible(joueur, position_depart_cellule, cellule_vers_monde(destination)):
		return false
	var direction: Vector2i = destination - depart
	if bloquer_diagonale_coin and abs(direction.x) == 1 and abs(direction.y) == 1:
		var cellule_horizontale: Vector2i = depart + Vector2i(direction.x, 0)
		var cellule_verticale: Vector2i = depart + Vector2i(0, direction.y)
		if not _cellule_logiquement_disponible_pour_joueur(cellule_horizontale) or not _cellule_logiquement_disponible_pour_joueur(cellule_verticale):
			return false
		if not _segment_est_accessible(joueur, position_depart_cellule, cellule_vers_monde(cellule_horizontale)):
			return false
		if not _segment_est_accessible(joueur, position_depart_cellule, cellule_vers_monde(cellule_verticale)):
			return false
	return true

func _cellule_est_accessible_simple(joueur: CharacterBody2D, cellule: Vector2i) -> bool:
	return _segment_est_accessible(joueur, joueur.global_position, cellule_vers_monde(cellule))

func _segment_est_accessible(joueur: CharacterBody2D, depart: Vector2, arrivee: Vector2, rids_a_ignorer: Array = []) -> bool:
	if joueur is Player and not (joueur as Player).position_respecte_limites_deplacement(arrivee):
		return false
	var collision := _obtenir_collision_joueur(joueur)
	if collision == null or collision.shape == null:
		return true
	var parametres := PhysicsShapeQueryParameters2D.new()
	parametres.shape = collision.shape
	parametres.transform = collision.global_transform
	parametres.transform.origin += depart - joueur.global_position
	parametres.collision_mask = joueur.collision_mask
	parametres.collide_with_bodies = true
	parametres.collide_with_areas = false
	var exclusions: Array[RID] = [joueur.get_rid()]
	for valeur in rids_a_ignorer:
		var rid: RID = valeur
		if not exclusions.has(rid):
			exclusions.append(rid)
	parametres.exclude = exclusions
	parametres.motion = arrivee - depart
	var espace: PhysicsDirectSpaceState2D = joueur.get_world_2d().direct_space_state
	var fractions: PackedFloat32Array = espace.cast_motion(parametres)
	if fractions.is_empty() or fractions[0] < 0.9999:
		return false
	parametres.transform.origin += parametres.motion
	parametres.motion = Vector2.ZERO
	return espace.intersect_shape(parametres, 1).is_empty()

func _cellule_logiquement_disponible_pour_joueur(cellule: Vector2i) -> bool:
	_resoudre_gestionnaire_parcours()
	if _gestionnaire_parcours == null or not _gestionnaire_parcours.has_method("cellule_est_disponible_pour_joueur"):
		return true
	return bool(_gestionnaire_parcours.call("cellule_est_disponible_pour_joueur", cellule))

func _obtenir_occupant_parcours(cellule: Vector2i) -> Node:
	_resoudre_gestionnaire_parcours()
	if _gestionnaire_parcours == null or not _gestionnaire_parcours.has_method("obtenir_occupant"):
		return null
	return _gestionnaire_parcours.call("obtenir_occupant", cellule) as Node

func _occupant_autorise_joueur(occupant: Node) -> bool:
	if occupant == null:
		return true
	_resoudre_gestionnaire_parcours()
	if _gestionnaire_parcours == null or not _gestionnaire_parcours.has_method("occupant_autorise_joueur"):
		return false
	return bool(_gestionnaire_parcours.call("occupant_autorise_joueur", occupant))

func _obtenir_collision_joueur(joueur: CharacterBody2D) -> CollisionShape2D:
	for enfant in joueur.get_children():
		var collision := enfant as CollisionShape2D
		if collision != null and not collision.disabled and collision.shape != null:
			return collision
	return null

func _obtenir_controleur(joueur: CharacterBody2D) -> GestionDeplacementJoueur:
	if joueur is Player:
		return (joueur as Player).gestion_deplacement
	return null

func _resoudre_gestionnaire_grille() -> void:
	if _gestionnaire_grille == null or not is_instance_valid(_gestionnaire_grille):
		_gestionnaire_grille = get_tree().get_first_node_in_group("grille_combat") as GestionnaireGrilleCombat

func _resoudre_gestionnaire_parcours() -> void:
	if _gestionnaire_parcours == null or not is_instance_valid(_gestionnaire_parcours):
		_gestionnaire_parcours = get_tree().get_first_node_in_group("gestionnaire_parcours_grille")

func _interrompre_transport_source(joueur: CharacterBody2D) -> void:
	if not _transport_plateforme_actif:
		return
	var source: Node = _transport_plateforme_source
	if source != null and is_instance_valid(source) and source.has_method("interrompre_transport_passager"):
		source.call("interrompre_transport_passager", joueur)
	_transport_plateforme_actif = false
	_transport_plateforme_source = null

func _appliquer_courbe_interpolation(t: float) -> float:
	var progression: float = clampf(t, 0.0, 1.0)
	if courbe_interpolation == CourbeInterpolation.LINEAIRE:
		return progression
	return progression * progression * (3.0 - 2.0 * progression)

func _obtenir_direction_entree(autoriser_diagonale: bool = false) -> Vector2i:
	var droite_appuyee: bool = Input.get_action_strength("droite") > 0.0 and _direction_dash_a_relacher.x != 1
	var gauche_appuyee: bool = Input.get_action_strength("gauche") > 0.0 and _direction_dash_a_relacher.x != -1
	var bas_appuye: bool = Input.get_action_strength("bas") > 0.0 and _direction_dash_a_relacher.y != 1
	var haut_appuye: bool = Input.get_action_strength("haut") > 0.0 and _direction_dash_a_relacher.y != -1
	var x: int = int(droite_appuyee) - int(gauche_appuyee)
	var y: int = int(bas_appuye) - int(haut_appuye)
	if autoriser_diagonale:
		return Vector2i(x, y)
	return _limiter_direction(Vector2i(x, y))

func _mettre_a_jour_direction_dash_a_relacher() -> void:
	if _direction_dash_a_relacher.x == 1 and not Input.is_action_pressed("droite"):
		_direction_dash_a_relacher.x = 0
	elif _direction_dash_a_relacher.x == -1 and not Input.is_action_pressed("gauche"):
		_direction_dash_a_relacher.x = 0
	if _direction_dash_a_relacher.y == 1 and not Input.is_action_pressed("bas"):
		_direction_dash_a_relacher.y = 0
	elif _direction_dash_a_relacher.y == -1 and not Input.is_action_pressed("haut"):
		_direction_dash_a_relacher.y = 0

func _filtrer_direction_dash_a_relacher(direction: Vector2i) -> Vector2i:
	var direction_filtree: Vector2i = direction
	if direction_filtree.x == _direction_dash_a_relacher.x:
		direction_filtree.x = 0
	if direction_filtree.y == _direction_dash_a_relacher.y:
		direction_filtree.y = 0
	return direction_filtree

func _obtenir_direction_juste_appuyee(direction_maintenue: Vector2i) -> Vector2i:
	var horizontal_appuye: bool = Input.is_action_just_pressed("gauche") or Input.is_action_just_pressed("droite")
	var vertical_appuye: bool = Input.is_action_just_pressed("haut") or Input.is_action_just_pressed("bas")
	if not horizontal_appuye and not vertical_appuye:
		return Vector2i.ZERO
	if diagonales_autorisees:
		return direction_maintenue
	if horizontal_appuye:
		return Vector2i(direction_maintenue.x, 0)
	return Vector2i(0, direction_maintenue.y)

func _limiter_direction(direction: Vector2i) -> Vector2i:
	var limitee := Vector2i(clampi(direction.x, -1, 1), clampi(direction.y, -1, 1))
	if diagonales_autorisees or limitee.x == 0 or limitee.y == 0:
		return limitee
	if abs(direction.x) >= abs(direction.y):
		return Vector2i(limitee.x, 0)
	return Vector2i(0, limitee.y)

func _limiter_direction_dash(direction: Vector2i) -> Vector2i:
	return Vector2i(clampi(direction.x, -1, 1), clampi(direction.y, -1, 1))

func _mettre_a_jour_maintien(direction: Vector2i, dt: float) -> void:
	if direction == Vector2i.ZERO or not maintien_touche_actif:
		_direction_maintenue_precedente = direction
		_temps_maintien_s = 0.0
		_temps_depuis_repetition_s = 0.0
		return
	if direction != _direction_maintenue_precedente:
		_direction_maintenue_precedente = direction
		_temps_maintien_s = 0.0
		_temps_depuis_repetition_s = 0.0
		return
	_temps_maintien_s += dt
	_temps_depuis_repetition_s += dt

func _reinitialiser_maintien() -> void:
	_direction_maintenue_precedente = Vector2i.ZERO
	_temps_maintien_s = 0.0
	_temps_depuis_repetition_s = 0.0

func _repetition_maintien_prete(direction: Vector2i) -> bool:
	if not maintien_touche_actif or direction == Vector2i.ZERO:
		return false
	return _temps_maintien_s >= delai_repetition_initial_s and _temps_depuis_repetition_s >= intervalle_repetition_s

func _memoriser_direction_buffer(direction: Vector2i) -> void:
	if not buffer_entree_actif or direction == Vector2i.ZERO:
		return
	_direction_buffer = direction
	_temps_buffer_restant_s = duree_buffer_entree_s

func _mettre_a_jour_temps_buffers(dt: float) -> void:
	if _temps_buffer_restant_s > 0.0:
		_temps_buffer_restant_s = maxf(0.0, _temps_buffer_restant_s - dt)
		if _temps_buffer_restant_s <= 0.0:
			_effacer_direction_buffer()

func _effacer_direction_buffer() -> void:
	_direction_buffer = Vector2i.ZERO
	_temps_buffer_restant_s = 0.0

func _signaler_refus(cellule: Vector2i) -> void:
	_cellule_refusee_debug = cellule
	_cellule_refusee_presente = true
	deplacement_refuse.emit(cellule)
	_cellule_refusee_presente = false

func _appliquer_soif_distance(joueur: CharacterBody2D, distance: float) -> void:
	if not joueur is Player:
		return
	var player_move := joueur as Player
	var controleur := player_move.gestion_deplacement
	if player_move.soif != null and is_instance_valid(player_move.soif) and controleur != null:
		player_move.soif.perdre_soif(distance / controleur.obtenir_distance_par_point_soif())

func _mettre_a_jour_recharge_dash(joueur: CharacterBody2D, stats: StatsJoueur, dt: float) -> void:
	if stats == null:
		return
	var dash_max: int = stats.get_dash_max_effectif()
	var dash_cooldown_s: float = stats.get_dash_cooldown_effectif()
	joueur.dash_cooldown_s = dash_cooldown_s
	joueur.dash_charges_actuelles = mini(joueur.dash_charges_actuelles, dash_max)
	if not joueur.dash_infini_actif and joueur.dash_charges_actuelles < dash_max and not _en_dash:
		joueur.dash_timer_recup_s += dt
		if joueur.dash_timer_recup_s >= dash_cooldown_s:
			joueur.dash_timer_recup_s -= dash_cooldown_s
			joueur.dash_charges_actuelles = mini(joueur.dash_charges_actuelles + 1, dash_max)

func _reinitialiser_etat_transitoire(joueur: CharacterBody2D) -> void:
	_terminer_poussee_coordonne()
	_en_deplacement = false
	_en_dash = false
	_deplacement_force = false
	_transport_plateforme_actif = false
	_transport_plateforme_source = null
	_temps_deplacement_s = 0.0
	_duree_deplacement_s = 0.0
	_reinitialiser_maintien()
	_effacer_direction_buffer()
	_dash_en_preparation = false
	_preparation_dash_en_attente = false
	_direction_dash_preparee = Vector2i.ZERO
	_direction_dash_a_relacher = Vector2i.ZERO
	_chemin_dash_debug.clear()
	_cellule_refusee_presente = false
	joueur.dash_t_restant_s = 0.0
	joueur.dash_direction = Vector2.ZERO
