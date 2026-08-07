extends ElementParcours
class_name OccupantGrille

@export_group("Occupation")
@export var corps_collision: CollisionObject2D
@export var collision_shape: CollisionShape2D
@export_flags_2d_physics var masque_obstacles: int = 1
@export_range(0.01, 1.0, 0.01) var duree_deplacement_s: float = 0.12

var gestionnaire_parcours: GestionnaireParcoursGrille
var deplacement_grille: GestionDeplacementGrilleJoueur
var _enregistre: bool = false
var _en_deplacement_occupant: bool = false
var _deplacement_coordonne: bool = false
var _cellule_destination: Vector2i = Vector2i.ZERO
var _position_depart_occupant: Vector2 = Vector2.ZERO
var _position_destination_occupant: Vector2 = Vector2.ZERO
var _duree_deplacement_occupant_s: float = 0.0
var _temps_deplacement_occupant_s: float = 0.0

func initialiser_parcours(gestionnaire) -> void:
	gestionnaire_parcours = gestionnaire as GestionnaireParcoursGrille
	if gestionnaire_parcours == null:
		return
	deplacement_grille = gestionnaire_parcours.deplacement_grille
	if deplacement_grille == null:
		return
	_enregistre = gestionnaire_parcours.enregistrer_occupant(self, cellule)
	set_process(false)

func autorise_joueur_sur_cellule() -> bool:
	return false

func est_deplacable_manuellement_par_joueur() -> bool:
	return false

func peut_deplacer_manuellement_par_joueur(_joueur: CharacterBody2D, _direction: Vector2i) -> bool:
	return false

func demarrer_deplacement_manuel_par_joueur(_joueur: CharacterBody2D, _direction: Vector2i) -> bool:
	return false

func peut_etre_pousse_par_joueur(_joueur: CharacterBody2D, _direction: Vector2i) -> bool:
	return false

func demarrer_poussee_joueur(_joueur: CharacterBody2D, _direction: Vector2i, _duree_s: float) -> bool:
	return false

func est_en_deplacement_occupant() -> bool:
	return _en_deplacement_occupant

func obtenir_rids_collision_pour_joueur() -> Array[RID]:
	var resultat: Array[RID] = []
	if corps_collision != null and is_instance_valid(corps_collision):
		resultat.append(corps_collision.get_rid())
	return resultat

func destination_physiquement_accessible(joueur: CharacterBody2D, destination: Vector2i) -> bool:
	if deplacement_grille == null or collision_shape == null or collision_shape.shape == null:
		return true
	var delta_monde: Vector2 = deplacement_grille.cellule_vers_monde(destination) - deplacement_grille.cellule_vers_monde(cellule)
	var parametres := PhysicsShapeQueryParameters2D.new()
	parametres.shape = collision_shape.shape
	parametres.transform = collision_shape.global_transform
	parametres.collision_mask = masque_obstacles
	parametres.collide_with_bodies = true
	parametres.collide_with_areas = false
	var exclusions: Array[RID] = obtenir_rids_collision_pour_joueur()
	if joueur != null and is_instance_valid(joueur):
		exclusions.append(joueur.get_rid())
	parametres.exclude = exclusions
	parametres.motion = delta_monde
	var espace: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var fractions: PackedFloat32Array = espace.cast_motion(parametres)
	if fractions.is_empty() or fractions[0] < 0.9999:
		return false
	parametres.transform.origin += delta_monde
	parametres.motion = Vector2.ZERO
	return espace.intersect_shape(parametres, 1).is_empty()

func avancer_deplacement_coordonne(dt: float) -> void:
	if not _en_deplacement_occupant or not _deplacement_coordonne:
		return
	_avancer_deplacement_occupant(dt)

func terminer_deplacement_immediatement() -> void:
	if not _en_deplacement_occupant:
		return
	_temps_deplacement_occupant_s = _duree_deplacement_occupant_s
	_avancer_deplacement_occupant(0.0)

func _demarrer_deplacement_occupant(destination: Vector2i, duree_s: float, coordonne: bool) -> bool:
	if not _enregistre or gestionnaire_parcours == null or deplacement_grille == null or _en_deplacement_occupant:
		return false
	var reservations: Array[Vector2i] = [destination]
	if not gestionnaire_parcours.reserver_cellules_occupant(self, reservations):
		return false
	_cellule_destination = destination
	_position_depart_occupant = global_position
	var delta_monde: Vector2 = deplacement_grille.cellule_vers_monde(destination) - deplacement_grille.cellule_vers_monde(cellule)
	_position_destination_occupant = global_position + delta_monde
	_duree_deplacement_occupant_s = maxf(duree_s, 0.01)
	_temps_deplacement_occupant_s = 0.0
	_deplacement_coordonne = coordonne
	_en_deplacement_occupant = true
	_avant_deplacement_occupant(destination)
	set_process(not coordonne)
	return true

func _process(dt: float) -> void:
	if _en_deplacement_occupant and not _deplacement_coordonne:
		_avancer_deplacement_occupant(dt)

func _avancer_deplacement_occupant(dt: float) -> void:
	_temps_deplacement_occupant_s = minf(_temps_deplacement_occupant_s + dt, _duree_deplacement_occupant_s)
	var progression: float = _temps_deplacement_occupant_s / maxf(_duree_deplacement_occupant_s, 0.001)
	var progression_douce: float = progression * progression * (3.0 - 2.0 * progression)
	global_position = _position_depart_occupant.lerp(_position_destination_occupant, progression_douce)
	if _temps_deplacement_occupant_s < _duree_deplacement_occupant_s:
		return
	global_position = _position_destination_occupant
	var ancienne_cellule: Vector2i = cellule
	var destination: Vector2i = _cellule_destination
	var occuper_destination: bool = _doit_occuper_destination(destination)
	var reussi: bool = gestionnaire_parcours != null and gestionnaire_parcours.terminer_deplacement_occupant(self, ancienne_cellule, destination, occuper_destination)
	if reussi:
		cellule = destination
	else:
		global_position = _position_depart_occupant
	_en_deplacement_occupant = false
	_deplacement_coordonne = false
	_temps_deplacement_occupant_s = 0.0
	_duree_deplacement_occupant_s = 0.0
	set_process(false)
	_apres_deplacement_occupant(ancienne_cellule, destination, reussi, occuper_destination and reussi)

func _avant_deplacement_occupant(_destination: Vector2i) -> void:
	pass

func _doit_occuper_destination(_destination: Vector2i) -> bool:
	return true

func _apres_deplacement_occupant(_ancienne_cellule: Vector2i, _destination: Vector2i, _reussi: bool, _destination_occupee: bool) -> void:
	pass

func quand_sol_disparait(_cellule: Vector2i) -> void:
	pass

func _exit_tree() -> void:
	if gestionnaire_parcours != null and is_instance_valid(gestionnaire_parcours):
		gestionnaire_parcours.retirer_occupant(self, cellule)
