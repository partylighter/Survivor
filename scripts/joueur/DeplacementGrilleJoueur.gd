extends Node
class_name GestionDeplacementGrilleJoueur

signal cellule_quittee(cellule: Vector2i)
signal cellule_atteinte(cellule: Vector2i)
signal deplacement_refuse(cellule: Vector2i)
signal dash_grille_demarre(depart: Vector2i, destination: Vector2i)
signal dash_grille_termine(destination: Vector2i)

enum CourbeInterpolation {
	LINEAIRE,
	DOUCE
}

@export_group("Grille")
@export var taille_cellule_px: float = 48.0
@export var origine_grille: Vector2 = Vector2.ZERO
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

var cellule_actuelle: Vector2i = Vector2i.ZERO
var cellule_cible: Vector2i = Vector2i.ZERO
var position_depart: Vector2 = Vector2.ZERO
var position_cible: Vector2 = Vector2.ZERO
var _duree_deplacement_s: float = 0.0
var _temps_deplacement_s: float = 0.0
var _en_deplacement: bool = false
var _en_dash: bool = false
var _synchronise: bool = false
var _direction_derniere: Vector2i = Vector2i.RIGHT
var _direction_maintenue_precedente: Vector2i = Vector2i.ZERO
var _temps_maintien_s: float = 0.0
var _temps_depuis_repetition_s: float = 0.0
var _direction_buffer: Vector2i = Vector2i.ZERO
var _temps_buffer_restant_s: float = 0.0
var _dash_en_buffer: bool = false
var _temps_dash_buffer_restant_s: float = 0.0
var _chemin_dash_debug: Array[Vector2i] = []
var _cellule_refusee_debug: Vector2i = Vector2i.ZERO
var _cellule_refusee_presente: bool = false

func traiter(joueur: CharacterBody2D, stats: StatsJoueur, dt: float) -> void:
	if not _synchronise:
		synchroniser_sur_grille(joueur)
	_mettre_a_jour_recharge_dash(joueur, stats, dt)
	_mettre_a_jour_temps_buffers(dt)
	var direction_maintenue: Vector2i = _obtenir_direction_entree()
	var direction_juste_appuyee: Vector2i = _obtenir_direction_juste_appuyee(direction_maintenue)
	_mettre_a_jour_maintien(direction_maintenue, dt)
	if _en_deplacement:
		if direction_juste_appuyee != Vector2i.ZERO:
			_memoriser_direction_buffer(direction_juste_appuyee)
		if Input.is_action_just_pressed("dash"):
			_memoriser_dash_buffer()
		_avancer_deplacement(joueur, dt)
		if not _en_deplacement:
			_consomme_entree_apres_arrivee(joueur, stats, direction_maintenue)
		return
	joueur.velocity = Vector2.ZERO
	if Input.is_action_just_pressed("dash") and _essayer_demarrer_dash(joueur, stats, direction_maintenue):
		return
	if direction_juste_appuyee != Vector2i.ZERO:
		_essayer_demarrer_pas(joueur, stats, direction_juste_appuyee)
		return
	if _repetition_maintien_prete(direction_maintenue):
		_temps_depuis_repetition_s = 0.0
		_essayer_demarrer_pas(joueur, stats, direction_maintenue)

func synchroniser_sur_grille(joueur: CharacterBody2D) -> void:
	cellule_actuelle = monde_vers_cellule(joueur.global_position)
	cellule_cible = cellule_actuelle
	position_depart = cellule_vers_monde(cellule_actuelle)
	position_cible = position_depart
	joueur.global_position = position_depart
	joueur.velocity = Vector2.ZERO
	_reinitialiser_etat_transitoire(joueur)
	_synchronise = true

func interrompre_et_recaler(joueur: CharacterBody2D) -> void:
	if not _synchronise:
		synchroniser_sur_grille(joueur)
	else:
		joueur.global_position = cellule_vers_monde(cellule_actuelle)
		joueur.velocity = Vector2.ZERO
		_reinitialiser_etat_transitoire(joueur)

func obtenir_cellule_actuelle() -> Vector2i:
	return cellule_actuelle

func obtenir_cellule_cible() -> Vector2i:
	return cellule_cible

func est_en_deplacement() -> bool:
	return _en_deplacement

func est_en_dash() -> bool:
	return _en_dash

func cellule_vers_monde(cellule: Vector2i) -> Vector2:
	var taille: float = maxf(taille_cellule_px, 1.0)
	return origine_grille + Vector2(cellule) * taille

func monde_vers_cellule(position_monde: Vector2) -> Vector2i:
	var taille: float = maxf(taille_cellule_px, 1.0)
	var coordonnee: Vector2 = (position_monde - origine_grille) / taille
	return Vector2i(roundi(coordonnee.x), roundi(coordonnee.y))

func calculer_duree_pas(stats: StatsJoueur) -> float:
	var vitesse: float = vitesse_reference_px_s
	if stats != null:
		vitesse = maxf(stats.get_vitesse_effective(), 1.0)
	var reference: float = maxf(vitesse_reference_px_s, 1.0)
	var duree: float = duree_pas_s * reference / vitesse
	return clampf(duree, minf(duree_pas_min_s, duree_pas_max_s), maxf(duree_pas_min_s, duree_pas_max_s))

func cellule_est_accessible(joueur: CharacterBody2D, cellule: Vector2i, verifier_coins: bool = true) -> bool:
	if not _cellule_est_accessible_simple(joueur, cellule):
		return false
	var direction: Vector2i = cellule - cellule_actuelle
	if verifier_coins and bloquer_diagonale_coin and abs(direction.x) == 1 and abs(direction.y) == 1:
		var cellule_horizontale := cellule_actuelle + Vector2i(direction.x, 0)
		var cellule_verticale := cellule_actuelle + Vector2i(0, direction.y)
		if not _cellule_est_accessible_simple(joueur, cellule_horizontale):
			return false
		if not _cellule_est_accessible_simple(joueur, cellule_verticale):
			return false
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
	if not cellule_est_accessible(joueur, destination):
		_signaler_refus(destination)
		return false
	_direction_derniere = direction_valide
	var multiplicateur_diagonal: float = sqrt(2.0) if abs(direction_valide.x) == 1 and abs(direction_valide.y) == 1 else 1.0
	_demarrer_deplacement(joueur, destination, calculer_duree_pas(stats) * multiplicateur_diagonal, false)
	return true

func _essayer_demarrer_dash(joueur: CharacterBody2D, stats: StatsJoueur, direction_entree: Vector2i) -> bool:
	if not joueur.dash_autorise or joueur.dash_t_restant_s > 0.0:
		return false
	if not joueur.dash_infini_actif and joueur.dash_charges_actuelles <= 0:
		return false
	var direction: Vector2i = _limiter_direction(direction_entree)
	var controleur: GestionDeplacementJoueur = _obtenir_controleur(joueur)
	if direction == Vector2i.ZERO and controleur != null and controleur.dash_autorise_sans_direction():
		direction = _direction_derniere
	if direction == Vector2i.ZERO:
		return false
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
	var duree_dash: float = maxf(duree_dash_par_cellule_s, 0.01) * float(chemin.size())
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

func _demarrer_deplacement(joueur: CharacterBody2D, destination: Vector2i, duree: float, dash: bool) -> void:
	cellule_cible = destination
	position_depart = joueur.global_position
	position_cible = cellule_vers_monde(destination)
	_duree_deplacement_s = maxf(duree, 0.001)
	_temps_deplacement_s = 0.0
	_en_deplacement = true
	_en_dash = dash
	_cellule_refusee_presente = false
	cellule_quittee.emit(cellule_actuelle)

func _avancer_deplacement(joueur: CharacterBody2D, dt: float) -> void:
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
	joueur.global_position = position_cible
	cellule_actuelle = cellule_cible
	_en_deplacement = false
	_en_dash = false
	joueur.velocity = Vector2.ZERO
	cellule_atteinte.emit(cellule_actuelle)
	if etait_dash:
		joueur.dash_t_restant_s = 0.0
		dash_grille_termine.emit(cellule_actuelle)
	else:
		_appliquer_soif_distance(joueur, position_depart.distance_to(position_cible))

func _consomme_entree_apres_arrivee(joueur: CharacterBody2D, stats: StatsJoueur, direction_maintenue: Vector2i) -> void:
	if _dash_en_buffer and _temps_dash_buffer_restant_s > 0.0:
		_dash_en_buffer = false
		if _essayer_demarrer_dash(joueur, stats, direction_maintenue):
			return
	if _direction_buffer != Vector2i.ZERO and _temps_buffer_restant_s > 0.0:
		var direction: Vector2i = _direction_buffer
		_effacer_direction_buffer()
		if _essayer_demarrer_pas(joueur, stats, direction):
			return
	if _repetition_maintien_prete(direction_maintenue):
		_temps_depuis_repetition_s = 0.0
		_essayer_demarrer_pas(joueur, stats, direction_maintenue)

func _cellule_dash_est_accessible(joueur: CharacterBody2D, depart: Vector2i, destination: Vector2i) -> bool:
	if not _cellule_est_accessible_simple(joueur, destination):
		return false
	var direction: Vector2i = destination - depart
	if bloquer_diagonale_coin and abs(direction.x) == 1 and abs(direction.y) == 1:
		if not _cellule_est_accessible_simple(joueur, depart + Vector2i(direction.x, 0)):
			return false
		if not _cellule_est_accessible_simple(joueur, depart + Vector2i(0, direction.y)):
			return false
	return true

func _cellule_est_accessible_simple(joueur: CharacterBody2D, cellule: Vector2i) -> bool:
	var position_monde: Vector2 = cellule_vers_monde(cellule)
	if joueur is Player and not (joueur as Player).position_respecte_limites_deplacement(position_monde):
		return false
	var collision := _obtenir_collision_joueur(joueur)
	if collision == null or collision.shape == null:
		return true
	var parametres := PhysicsShapeQueryParameters2D.new()
	parametres.shape = collision.shape
	parametres.transform = collision.global_transform
	parametres.transform.origin += position_monde - joueur.global_position
	parametres.collision_mask = joueur.collision_mask
	parametres.collide_with_bodies = true
	parametres.collide_with_areas = false
	parametres.exclude = [joueur.get_rid()]
	return joueur.get_world_2d().direct_space_state.intersect_shape(parametres, 1).is_empty()

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

func _appliquer_courbe_interpolation(t: float) -> float:
	var progression: float = clampf(t, 0.0, 1.0)
	if courbe_interpolation == CourbeInterpolation.LINEAIRE:
		return progression
	return progression * progression * (3.0 - 2.0 * progression)

func _obtenir_direction_entree() -> Vector2i:
	var x: int = int(Input.get_action_strength("droite") > 0.0) - int(Input.get_action_strength("gauche") > 0.0)
	var y: int = int(Input.get_action_strength("bas") > 0.0) - int(Input.get_action_strength("haut") > 0.0)
	return _limiter_direction(Vector2i(x, y))

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

func _repetition_maintien_prete(direction: Vector2i) -> bool:
	if not maintien_touche_actif or direction == Vector2i.ZERO:
		return false
	return _temps_maintien_s >= delai_repetition_initial_s and _temps_depuis_repetition_s >= intervalle_repetition_s

func _memoriser_direction_buffer(direction: Vector2i) -> void:
	if not buffer_entree_actif or direction == Vector2i.ZERO:
		return
	_direction_buffer = direction
	_temps_buffer_restant_s = duree_buffer_entree_s

func _memoriser_dash_buffer() -> void:
	if not buffer_entree_actif:
		return
	_dash_en_buffer = true
	_temps_dash_buffer_restant_s = duree_buffer_entree_s

func _mettre_a_jour_temps_buffers(dt: float) -> void:
	if _temps_buffer_restant_s > 0.0:
		_temps_buffer_restant_s = maxf(0.0, _temps_buffer_restant_s - dt)
		if _temps_buffer_restant_s <= 0.0:
			_effacer_direction_buffer()
	if _temps_dash_buffer_restant_s > 0.0:
		_temps_dash_buffer_restant_s = maxf(0.0, _temps_dash_buffer_restant_s - dt)
		if _temps_dash_buffer_restant_s <= 0.0:
			_dash_en_buffer = false

func _effacer_direction_buffer() -> void:
	_direction_buffer = Vector2i.ZERO
	_temps_buffer_restant_s = 0.0

func _signaler_refus(cellule: Vector2i) -> void:
	_cellule_refusee_debug = cellule
	_cellule_refusee_presente = true
	deplacement_refuse.emit(cellule)

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
	_en_deplacement = false
	_en_dash = false
	_temps_deplacement_s = 0.0
	_duree_deplacement_s = 0.0
	_direction_maintenue_precedente = Vector2i.ZERO
	_temps_maintien_s = 0.0
	_temps_depuis_repetition_s = 0.0
	_effacer_direction_buffer()
	_dash_en_buffer = false
	_temps_dash_buffer_restant_s = 0.0
	_chemin_dash_debug.clear()
	_cellule_refusee_presente = false
	joueur.dash_t_restant_s = 0.0
	joueur.dash_direction = Vector2.ZERO
