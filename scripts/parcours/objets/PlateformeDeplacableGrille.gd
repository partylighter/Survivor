extends OccupantGrille
class_name PlateformeDeplacableGrille

signal ramassee(joueur: CharacterBody2D)
signal deposee(cellule: Vector2i)
signal depot_refuse(cellule: Vector2i)
signal portage_interrompu(cellule: Vector2i)

@export_group("Portage")
@export var decalage_visuel_portage: Vector2 = Vector2(0.0, -180.0)

var _est_portee: bool = false
var _porteur: CharacterBody2D
var _cellule_dernier_depot: Vector2i = Vector2i.ZERO

func initialiser_parcours(gestionnaire) -> void:
	super(gestionnaire)
	_cellule_dernier_depot = cellule
	if _enregistre and gestionnaire_parcours != null:
		gestionnaire_parcours.enregistrer_sol_dynamique(self, cellule)
		if not gestionnaire_parcours.joueur_tombe.is_connected(_quand_joueur_tombe):
			gestionnaire_parcours.joueur_tombe.connect(_quand_joueur_tombe)
	set_physics_process(false)

func autorise_joueur_sur_cellule() -> bool:
	return not _est_portee

func autorise_reapparition_sur_sol() -> bool:
	return false

func est_ramassable_par_joueur() -> bool:
	return _enregistre and not _est_portee and not _en_deplacement_occupant

func peut_etre_ramassee_par_joueur(joueur: CharacterBody2D) -> bool:
	if not est_ramassable_par_joueur() or joueur == null or not is_instance_valid(joueur) or deplacement_grille == null:
		return false
	var cellule_joueur: Vector2i = deplacement_grille.obtenir_cellule_actuelle()
	var delta: Vector2i = cellule - cellule_joueur
	return abs(delta.x) + abs(delta.y) == 1

func ramasser_par_joueur(joueur: CharacterBody2D) -> bool:
	if not peut_etre_ramassee_par_joueur(joueur) or gestionnaire_parcours == null:
		return false
	_cellule_dernier_depot = cellule
	gestionnaire_parcours.retirer_occupant(self, cellule)
	_enregistre = false
	gestionnaire_parcours.retirer_sol_dynamique(self, cellule)
	_porteur = joueur
	_est_portee = true
	global_position = joueur.global_position + decalage_visuel_portage
	set_physics_process(true)
	ramassee.emit(joueur)
	return true

func est_portee_par_joueur(joueur: CharacterBody2D) -> bool:
	return _est_portee and _porteur == joueur

func deposer_par_joueur(joueur: CharacterBody2D, destination: Vector2i) -> bool:
	if not est_portee_par_joueur(joueur) or deplacement_grille == null:
		return false
	if deplacement_grille.est_en_deplacement() or deplacement_grille.est_en_transport_plateforme():
		return false
	var cellule_joueur: Vector2i = deplacement_grille.obtenir_cellule_actuelle()
	var delta: Vector2i = destination - cellule_joueur
	if abs(delta.x) + abs(delta.y) != 1:
		depot_refuse.emit(destination)
		return false
	if not _poser_sur_cellule(joueur, destination, true):
		depot_refuse.emit(destination)
		return false
	return true

func interrompre_portage_joueur(joueur: CharacterBody2D, cellule_secours: Vector2i) -> bool:
	if not est_portee_par_joueur(joueur):
		return false
	var destinations: Array[Vector2i] = _trouver_cellule_restauration(joueur, cellule_secours)
	if destinations.is_empty():
		push_warning("PlateformeDeplacableGrille: aucune cellule libre pour interrompre le portage.")
		return false
	var destination: Vector2i = destinations[0]
	if not _poser_sur_cellule(joueur, destination, false):
		return false
	portage_interrompu.emit(destination)
	_notifier_fin_portage_deplacement()
	return true

func _physics_process(_dt: float) -> void:
	if not _est_portee:
		return
	if _porteur == null or not is_instance_valid(_porteur):
		var destinations: Array[Vector2i] = _trouver_cellule_restauration(null, _cellule_dernier_depot)
		if not destinations.is_empty() and _poser_sur_cellule(null, destinations[0], false):
			_notifier_fin_portage_deplacement()
		else:
			push_warning("PlateformeDeplacableGrille: porteur perdu sans cellule de restauration disponible.")
		return
	global_position = _porteur.global_position + decalage_visuel_portage

func _poser_sur_cellule(joueur: CharacterBody2D, destination: Vector2i, verifier_trajet: bool) -> bool:
	if gestionnaire_parcours == null or deplacement_grille == null:
		return false
	if not gestionnaire_parcours.cellule_disponible_pour_occupant(destination, self):
		return false
	if not _depot_physiquement_accessible(joueur, destination, verifier_trajet):
		return false
	var reservations: Array[Vector2i] = [destination]
	if not gestionnaire_parcours.reserver_cellules_occupant(self, reservations):
		return false
	var position_portee: Vector2 = global_position
	global_position = deplacement_grille.cellule_vers_monde(destination)
	if not gestionnaire_parcours.enregistrer_occupant(self, destination):
		gestionnaire_parcours.liberer_reservations_occupant(self)
		global_position = position_portee
		return false
	gestionnaire_parcours.liberer_reservations_occupant(self)
	cellule = destination
	_cellule_dernier_depot = destination
	_enregistre = true
	gestionnaire_parcours.enregistrer_sol_dynamique(self, destination)
	_est_portee = false
	_porteur = null
	set_physics_process(false)
	deposee.emit(destination)
	return true

func _depot_physiquement_accessible(joueur: CharacterBody2D, destination: Vector2i, verifier_trajet: bool) -> bool:
	if collision_shape == null or collision_shape.shape == null or deplacement_grille == null:
		return true
	var destination_monde: Vector2 = deplacement_grille.cellule_vers_monde(destination)
	var decalage_forme: Vector2 = collision_shape.global_position - global_position
	var parametres := PhysicsShapeQueryParameters2D.new()
	parametres.shape = collision_shape.shape
	parametres.transform = collision_shape.global_transform
	parametres.collision_mask = masque_obstacles
	parametres.collide_with_bodies = true
	parametres.collide_with_areas = false
	var exclusions: Array[RID] = obtenir_rids_collision_pour_joueur()
	if joueur != null and is_instance_valid(joueur) and not exclusions.has(joueur.get_rid()):
		exclusions.append(joueur.get_rid())
	parametres.exclude = exclusions
	if verifier_trajet and joueur != null and is_instance_valid(joueur):
		var depart_monde: Vector2 = deplacement_grille.cellule_vers_monde(deplacement_grille.obtenir_cellule_actuelle())
		parametres.transform.origin = depart_monde + decalage_forme
		parametres.motion = destination_monde - depart_monde
		var espace_trajet: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var fractions: PackedFloat32Array = espace_trajet.cast_motion(parametres)
		if fractions.is_empty() or fractions[0] < 0.9999:
			return false
	parametres.transform.origin = destination_monde + decalage_forme
	parametres.motion = Vector2.ZERO
	var espace: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	return espace.intersect_shape(parametres, 1).is_empty()

func _trouver_cellule_restauration(joueur: CharacterBody2D, cellule_secours: Vector2i) -> Array[Vector2i]:
	var candidats: Array[Vector2i] = []
	_ajouter_candidat_unique(candidats, _cellule_dernier_depot)
	_ajouter_candidat_unique(candidats, cellule_secours)
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		_ajouter_candidat_unique(candidats, cellule_secours + direction)
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		_ajouter_candidat_unique(candidats, _cellule_dernier_depot + direction)
	for candidat in candidats:
		if gestionnaire_parcours.cellule_disponible_pour_occupant(candidat, self) and _depot_physiquement_accessible(joueur, candidat, false):
			return [candidat]
	return []

func _ajouter_candidat_unique(candidats: Array[Vector2i], cellule_candidate: Vector2i) -> void:
	if not candidats.has(cellule_candidate):
		candidats.append(cellule_candidate)

func _quand_joueur_tombe(_cellule: Vector2i, reapparition: Vector2i) -> void:
	if not _est_portee or _porteur == null or gestionnaire_parcours == null or _porteur != gestionnaire_parcours.joueur:
		return
	var joueur_porteur: CharacterBody2D = _porteur
	if interrompre_portage_joueur(joueur_porteur, reapparition):
		return
	push_warning("PlateformeDeplacableGrille: le portage est conservé après la chute faute de cellule de restauration.")

func _notifier_fin_portage_deplacement() -> void:
	if deplacement_grille != null and is_instance_valid(deplacement_grille) and deplacement_grille.has_method("oublier_objet_porte"):
		deplacement_grille.call("oublier_objet_porte", self)

func _exit_tree() -> void:
	_notifier_fin_portage_deplacement()
	if gestionnaire_parcours != null and is_instance_valid(gestionnaire_parcours):
		if gestionnaire_parcours.joueur_tombe.is_connected(_quand_joueur_tombe):
			gestionnaire_parcours.joueur_tombe.disconnect(_quand_joueur_tombe)
		if _enregistre:
			gestionnaire_parcours.retirer_sol_dynamique(self, cellule)
	super()
