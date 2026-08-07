extends ElementParcours
class_name PlateformeMobileGrille

signal segment_demarre(depart: Vector2i, destination: Vector2i)
signal cellule_atteinte_plateforme(cellule: Vector2i)
signal trajet_bloque(destination: Vector2i)
signal cycle_termine()

enum ModeTrajet {
	BOUCLE,
	ALLER_RETOUR
}

@export_group("Trajet")
@export var points_trajet: Node2D
@export var mode_trajet: ModeTrajet = ModeTrajet.ALLER_RETOUR
@export_range(0.01, 3.0, 0.01) var duree_par_cellule_s: float = 0.10
@export_range(0.0, 10.0, 0.05) var attente_entre_deplacements_s: float = 0.75
@export var demarrer_automatiquement: bool = true
@export var transporter_joueur: bool = true

@export_group("Collisions")
@export var forme_collision: CollisionShape2D
@export_flags_2d_physics var masque_obstacles: int = 1

var _gestionnaire: GestionnaireParcoursGrille
var _deplacement_grille: GestionDeplacementGrilleJoueur
var _joueur: CharacterBody2D
var _cellules_trajet: Array[Vector2i] = []
var _attentes_trajet: Array[float] = []
var _index_trajet: int = 0
var _sens_trajet: int = 1
var _index_depart_segment: int = 0
var _index_destination: int = 0
var _cellule_depart_segment: Vector2i = Vector2i.ZERO
var _cellule_destination: Vector2i = Vector2i.ZERO
var _position_depart: Vector2 = Vector2.ZERO
var _position_destination: Vector2 = Vector2.ZERO
var _duree_segment_s: float = 0.0
var _temps_segment_s: float = 0.0
var _attente_restant_s: float = 0.0
var _en_deplacement: bool = false
var _enregistre_occupation: bool = false
var _trajet_valide: bool = false
var _actif: bool = false
var _pause: bool = false
var _arret_demande: bool = false
var _passager: CharacterBody2D

func initialiser_parcours(gestionnaire) -> void:
	_gestionnaire = gestionnaire as GestionnaireParcoursGrille
	if _gestionnaire == null:
		return
	_deplacement_grille = _gestionnaire.deplacement_grille
	_joueur = _gestionnaire.joueur
	if _deplacement_grille == null:
		return
	_trajet_valide = _construire_trajet()
	_enregistre_occupation = _gestionnaire.enregistrer_occupant(self, cellule)
	if not _enregistre_occupation:
		set_physics_process(false)
		return
	_gestionnaire.enregistrer_sol_dynamique(self, cellule)
	_attente_restant_s = _attente_index(_index_trajet)
	_actif = demarrer_automatiquement and _trajet_valide
	set_process(false)
	set_physics_process(_actif)

func doit_etre_active_par_arrivee_joueur() -> bool:
	return false

func autorise_joueur_sur_cellule() -> bool:
	return not _en_deplacement

func autorise_reapparition_sur_sol() -> bool:
	return false

func demarrer() -> void:
	if not _trajet_valide or not _enregistre_occupation:
		return
	_actif = true
	_pause = false
	_arret_demande = false
	set_physics_process(true)

func arreter() -> void:
	if _en_deplacement:
		_arret_demande = true
		return
	_actif = false
	_arret_demande = false
	set_physics_process(false)

func mettre_en_pause() -> void:
	_pause = true

func reprendre() -> void:
	if not _trajet_valide or not _actif:
		return
	_pause = false
	set_physics_process(true)

func est_en_mouvement() -> bool:
	return _en_deplacement

func est_active() -> bool:
	return _actif

func _physics_process(dt: float) -> void:
	if not _actif or _pause:
		return
	if _en_deplacement:
		_avancer_segment(dt)
		return
	_attente_restant_s = maxf(_attente_restant_s - dt, 0.0)
	if _attente_restant_s > 0.0:
		return
	_demarrer_segment_suivant()

func _construire_trajet() -> bool:
	_cellules_trajet.clear()
	_attentes_trajet.clear()
	_cellules_trajet.append(cellule)
	_attentes_trajet.append(maxf(attente_entre_deplacements_s, 0.0))
	var conteneur: Node2D = points_trajet
	if conteneur == null:
		conteneur = get_node_or_null("PointsTrajet") as Node2D
	if conteneur == null:
		push_error("PlateformeMobileGrille: PointsTrajet introuvable.")
		return false
	var points: Array[PointTrajetPlateforme] = []
	for enfant in conteneur.get_children():
		var point := enfant as PointTrajetPlateforme
		if point != null:
			points.append(point)
	if points.is_empty():
		push_error("PlateformeMobileGrille: aucun PointTrajetPlateforme configuré.")
		return false
	points.sort_custom(Callable(self, "_point_trajet_avant"))
	for index in range(points.size()):
		if points[index].ordre != index + 1:
			push_error("PlateformeMobileGrille: les ordres des points doivent être uniques et continus à partir de 1.")
			return false
	var cellule_courante: Vector2i = cellule
	for point in points:
		var cellule_point: Vector2i = _deplacement_grille.monde_vers_cellule(point.global_position)
		var attente_point: float = maxf(attente_entre_deplacements_s, 0.0) + maxf(point.attente_s, 0.0)
		if cellule_point == cellule_courante:
			_attentes_trajet[_attentes_trajet.size() - 1] = maxf(_attentes_trajet.back(), attente_point)
			continue
		if not _segment_aligne(cellule_courante, cellule_point):
			push_error("PlateformeMobileGrille: segment diagonal invalide %s -> %s." % [str(cellule_courante), str(cellule_point)])
			return false
		_ajouter_segment_cellulaire(cellule_courante, cellule_point, attente_point)
		cellule_courante = cellule_point
	if mode_trajet == ModeTrajet.BOUCLE and not _fermer_boucle(cellule_courante):
		return false
	return _cellules_trajet.size() > 1

func _point_trajet_avant(a: PointTrajetPlateforme, b: PointTrajetPlateforme) -> bool:
	return a.ordre < b.ordre

func _segment_aligne(depart: Vector2i, destination: Vector2i) -> bool:
	var delta: Vector2i = destination - depart
	return delta != Vector2i.ZERO and (delta.x == 0 or delta.y == 0)

func _ajouter_segment_cellulaire(depart: Vector2i, destination: Vector2i, attente_destination: float) -> void:
	var delta: Vector2i = destination - depart
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	var distance: int = maxi(abs(delta.x), abs(delta.y))
	for index in range(1, distance + 1):
		_cellules_trajet.append(depart + direction * index)
		_attentes_trajet.append(attente_destination if index == distance else 0.0)

func _fermer_boucle(cellule_courante: Vector2i) -> bool:
	if cellule_courante == cellule:
		if _cellules_trajet.size() > 1:
			var attente_retour: float = _attentes_trajet.back()
			_cellules_trajet.pop_back()
			_attentes_trajet.pop_back()
			_attentes_trajet[0] = maxf(_attentes_trajet[0], attente_retour)
		return _cellules_trajet.size() > 1
	if not _segment_aligne(cellule_courante, cellule):
		push_error("PlateformeMobileGrille: fermeture de boucle diagonale invalide %s -> %s." % [str(cellule_courante), str(cellule)])
		return false
	var delta: Vector2i = cellule - cellule_courante
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	var distance: int = maxi(abs(delta.x), abs(delta.y))
	for index in range(1, distance):
		_cellules_trajet.append(cellule_courante + direction * index)
		_attentes_trajet.append(0.0)
	return true

func _demarrer_segment_suivant() -> void:
	var prochain_index: int = _obtenir_prochain_index()
	if prochain_index < 0:
		arreter()
		return
	var destination: Vector2i = _cellules_trajet[prochain_index]
	var delta: Vector2i = destination - cellule
	if abs(delta.x) + abs(delta.y) != 1:
		push_error("PlateformeMobileGrille: trajet interne non adjacent %s -> %s." % [str(cellule), str(destination)])
		arreter()
		return
	_resoudre_joueur()
	if not _destination_logiquement_libre(destination) or not _destination_physiquement_accessible(destination) or _joueur_bloque_segment(destination):
		_signaler_blocage(destination)
		return
	var reservations: Array[Vector2i] = [destination]
	if not _gestionnaire.reserver_cellules_occupant(self, reservations):
		_signaler_blocage(destination)
		return
	_passager = null
	if _joueur != null and is_instance_valid(_joueur) and _deplacement_grille.obtenir_cellule_actuelle() == cellule:
		if transporter_joueur:
			if not _deplacement_grille.commencer_transport_plateforme(_joueur, self, destination):
				_gestionnaire.liberer_reservations_occupant(self)
				_signaler_blocage(destination)
				return
			_passager = _joueur
	_index_depart_segment = _index_trajet
	_index_destination = prochain_index
	_cellule_depart_segment = cellule
	_cellule_destination = destination
	_position_depart = global_position
	var delta_monde: Vector2 = _deplacement_grille.cellule_vers_monde(destination) - _deplacement_grille.cellule_vers_monde(cellule)
	_position_destination = global_position + delta_monde
	_duree_segment_s = maxf(duree_par_cellule_s, 0.01)
	_temps_segment_s = 0.0
	_en_deplacement = true
	_gestionnaire.retirer_sol_dynamique(self, cellule)
	segment_demarre.emit(cellule, destination)

func _destination_logiquement_libre(destination: Vector2i) -> bool:
	return _gestionnaire != null and _gestionnaire.cellule_disponible_pour_occupant(destination, self)

func _destination_physiquement_accessible(destination: Vector2i) -> bool:
	if forme_collision == null or forme_collision.shape == null or _deplacement_grille == null:
		return true
	var delta_monde: Vector2 = _deplacement_grille.cellule_vers_monde(destination) - _deplacement_grille.cellule_vers_monde(cellule)
	var parametres := PhysicsShapeQueryParameters2D.new()
	parametres.shape = forme_collision.shape
	parametres.transform = forme_collision.global_transform
	parametres.collision_mask = masque_obstacles
	parametres.collide_with_bodies = true
	parametres.collide_with_areas = false
	var exclusions: Array[RID] = []
	if _joueur != null and is_instance_valid(_joueur):
		exclusions.append(_joueur.get_rid())
	parametres.exclude = exclusions
	parametres.motion = delta_monde
	var espace: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var fractions: PackedFloat32Array = espace.cast_motion(parametres)
	if fractions.is_empty() or fractions[0] < 0.9999:
		return false
	parametres.transform.origin += delta_monde
	parametres.motion = Vector2.ZERO
	return espace.intersect_shape(parametres, 1).is_empty()

func _joueur_bloque_segment(destination: Vector2i) -> bool:
	if _joueur == null or not is_instance_valid(_joueur) or _deplacement_grille == null:
		return false
	var cellule_joueur: Vector2i = _deplacement_grille.obtenir_cellule_actuelle()
	var cellule_cible_joueur: Vector2i = _deplacement_grille.obtenir_cellule_cible()
	if cellule_joueur == destination:
		return true
	if _deplacement_grille.est_en_deplacement():
		if cellule_joueur == cellule or cellule_cible_joueur == cellule or cellule_cible_joueur == destination:
			return true
	if _deplacement_grille.est_en_dash() and _deplacement_grille.obtenir_chemin_dash_debug().has(destination):
		return true
	return false

func _signaler_blocage(destination: Vector2i) -> void:
	_attente_restant_s = maxf(attente_entre_deplacements_s, 0.10)
	trajet_bloque.emit(destination)

func _avancer_segment(dt: float) -> void:
	if _passager != null and not is_instance_valid(_passager):
		_annuler_segment(false)
		return
	var ancienne_position: Vector2 = global_position
	_temps_segment_s = minf(_temps_segment_s + dt, _duree_segment_s)
	var progression: float = _temps_segment_s / maxf(_duree_segment_s, 0.001)
	var progression_douce: float = progression * progression * (3.0 - 2.0 * progression)
	global_position = _position_depart.lerp(_position_destination, progression_douce)
	var delta_monde: Vector2 = global_position - ancienne_position
	if _passager != null and is_instance_valid(_passager):
		_passager.global_position += delta_monde
		_passager.velocity = delta_monde / maxf(dt, 0.0001)
	if _temps_segment_s < _duree_segment_s:
		return
	global_position = _position_destination
	_terminer_segment()

func _terminer_segment() -> void:
	var ancienne_cellule: Vector2i = _cellule_depart_segment
	_gestionnaire.enregistrer_sol_dynamique(self, _cellule_destination)
	var occupation_confirmee: bool = _gestionnaire.terminer_deplacement_occupant(self, ancienne_cellule, _cellule_destination, true)
	if not occupation_confirmee:
		_gestionnaire.retirer_sol_dynamique(self, _cellule_destination)
		_annuler_segment(true)
		return
	cellule = _cellule_destination
	_index_trajet = _index_destination
	_en_deplacement = false
	if _passager != null and is_instance_valid(_passager):
		_deplacement_grille.terminer_transport_plateforme(_passager, self, cellule, true)
	_passager = null
	_temps_segment_s = 0.0
	_duree_segment_s = 0.0
	_attente_restant_s = _attente_index(_index_trajet)
	cellule_atteinte_plateforme.emit(cellule)
	_signaler_cycle_si_besoin()
	if _arret_demande:
		_actif = false
		_arret_demande = false
		set_physics_process(false)
		return
	if _actif and _attente_restant_s <= 0.0:
		_demarrer_segment_suivant()

func _annuler_segment(notifier_deplacement: bool) -> void:
	if not _en_deplacement:
		return
	global_position = _position_depart
	if _gestionnaire != null and is_instance_valid(_gestionnaire):
		_gestionnaire.liberer_reservations_occupant(self)
		_gestionnaire.enregistrer_sol_dynamique(self, _cellule_depart_segment)
	if notifier_deplacement and _passager != null and is_instance_valid(_passager) and _deplacement_grille != null:
		_deplacement_grille.annuler_transport_plateforme(_passager, self, _cellule_depart_segment)
	_passager = null
	_en_deplacement = false
	_temps_segment_s = 0.0
	_duree_segment_s = 0.0
	_attente_restant_s = maxf(attente_entre_deplacements_s, 0.0)

func interrompre_transport_passager(joueur: CharacterBody2D) -> void:
	if not _en_deplacement or _passager != joueur:
		return
	_annuler_segment(false)

func _obtenir_prochain_index() -> int:
	if _cellules_trajet.size() < 2:
		return -1
	if mode_trajet == ModeTrajet.BOUCLE:
		return (_index_trajet + 1) % _cellules_trajet.size()
	var prochain_index: int = _index_trajet + _sens_trajet
	if prochain_index < 0 or prochain_index >= _cellules_trajet.size():
		_sens_trajet *= -1
		prochain_index = _index_trajet + _sens_trajet
	return prochain_index

func _signaler_cycle_si_besoin() -> void:
	if mode_trajet == ModeTrajet.BOUCLE:
		if _index_trajet == 0 and _index_depart_segment != 0:
			cycle_termine.emit()
		return
	if _index_trajet == 0 and _sens_trajet < 0:
		cycle_termine.emit()

func _attente_index(index: int) -> float:
	if index < 0 or index >= _attentes_trajet.size():
		return 0.0
	return maxf(_attentes_trajet[index], 0.0)

func _resoudre_joueur() -> void:
	if _joueur != null and is_instance_valid(_joueur):
		return
	if _gestionnaire != null and is_instance_valid(_gestionnaire):
		_joueur = _gestionnaire.joueur
	if _joueur == null or not is_instance_valid(_joueur):
		_joueur = get_tree().get_first_node_in_group("joueur_principal") as CharacterBody2D

func _exit_tree() -> void:
	if _en_deplacement:
		_annuler_segment(true)
	if _gestionnaire == null or not is_instance_valid(_gestionnaire):
		return
	_gestionnaire.retirer_sol_dynamique(self, cellule)
	if _enregistre_occupation:
		_gestionnaire.retirer_occupant(self, cellule)
	else:
		_gestionnaire.liberer_reservations_occupant(self)
