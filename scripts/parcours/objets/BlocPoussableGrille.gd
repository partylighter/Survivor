extends OccupantGrille
class_name BlocPoussableGrille

enum ComportementVide {
	INTERDIT,
	TOMBE,
	RESTE
}

@export_group("Poussée")
@export var comportement_vide: ComportementVide = ComportementVide.RESTE

var _chaine_validee: Array[Node] = []
var _chaine_en_deplacement: bool = false
var _direction_chaine: Vector2i = Vector2i.ZERO
var _positions_depart_chaine: Array[Vector2] = []
var _positions_destination_chaine: Array[Vector2] = []
var _duree_chaine_s: float = 0.0
var _temps_chaine_s: float = 0.0

func peut_etre_pousse_par_joueur(joueur: CharacterBody2D, direction: Vector2i) -> bool:
	if _en_deplacement_occupant or _chaine_en_deplacement or gestionnaire_parcours == null:
		return false
	if abs(direction.x) + abs(direction.y) != 1:
		return false
	_chaine_validee = _construire_chaine_poussee(joueur, direction)
	return not _chaine_validee.is_empty()

func demarrer_poussee_joueur(joueur: CharacterBody2D, direction: Vector2i, duree_s: float) -> bool:
	if not peut_etre_pousse_par_joueur(joueur, direction):
		return false
	if not gestionnaire_parcours.reserver_poussee_chaine(self, _chaine_validee, direction):
		_chaine_validee.clear()
		return false
	_direction_chaine = direction
	_duree_chaine_s = maxf(duree_s, 0.01)
	_temps_chaine_s = 0.0
	_positions_depart_chaine.clear()
	_positions_destination_chaine.clear()
	for valeur in _chaine_validee:
		var bloc := valeur as BlocPoussableGrille
		if bloc == null:
			gestionnaire_parcours.liberer_reservations_occupant(self)
			_nettoyer_chaine(false)
			return false
		bloc._en_deplacement_occupant = true
		bloc.set_process(false)
		_positions_depart_chaine.append(bloc.global_position)
		var destination: Vector2i = bloc.cellule + direction
		var delta_monde: Vector2 = deplacement_grille.cellule_vers_monde(destination) - deplacement_grille.cellule_vers_monde(bloc.cellule)
		_positions_destination_chaine.append(bloc.global_position + delta_monde)
	_chaine_en_deplacement = true
	return true

func accepte_poussee_chaine() -> bool:
	return not _en_deplacement_occupant and not _chaine_en_deplacement

func accepte_destination_poussee(destination: Vector2i) -> bool:
	if gestionnaire_parcours == null:
		return false
	if comportement_vide == ComportementVide.INTERDIT and not gestionnaire_parcours.cellule_est_sure(destination):
		return false
	return true

func obtenir_rids_collision_pour_joueur() -> Array[RID]:
	if _chaine_validee.is_empty():
		return _obtenir_rids_propres()
	var resultat: Array[RID] = []
	for valeur in _chaine_validee:
		var bloc := valeur as BlocPoussableGrille
		if bloc == null:
			continue
		for rid in bloc._obtenir_rids_propres():
			if not resultat.has(rid):
				resultat.append(rid)
	return resultat

func avancer_deplacement_coordonne(dt: float) -> void:
	if not _chaine_en_deplacement:
		super(dt)
		return
	_temps_chaine_s = minf(_temps_chaine_s + dt, _duree_chaine_s)
	var progression: float = _temps_chaine_s / maxf(_duree_chaine_s, 0.001)
	var progression_douce: float = progression * progression * (3.0 - 2.0 * progression)
	for index in range(_chaine_validee.size()):
		var bloc := _chaine_validee[index] as BlocPoussableGrille
		if bloc != null and is_instance_valid(bloc):
			bloc.global_position = _positions_depart_chaine[index].lerp(_positions_destination_chaine[index], progression_douce)
	if _temps_chaine_s >= _duree_chaine_s:
		_terminer_poussee_chaine()

func terminer_deplacement_immediatement() -> void:
	if not _chaine_en_deplacement:
		super()
		return
	_temps_chaine_s = _duree_chaine_s
	avancer_deplacement_coordonne(0.0)

func _construire_chaine_poussee(joueur: CharacterBody2D, direction: Vector2i) -> Array[Node]:
	var chaine: Array[Node] = []
	var bloc_courant: BlocPoussableGrille = self
	while bloc_courant != null:
		if chaine.has(bloc_courant) or not bloc_courant.accepte_poussee_chaine():
			return []
		chaine.append(bloc_courant)
		var destination: Vector2i = bloc_courant.cellule + direction
		var occupant_suivant: Node = gestionnaire_parcours.obtenir_occupant(destination)
		if occupant_suivant == null:
			break
		var bloc_suivant := occupant_suivant as BlocPoussableGrille
		if bloc_suivant == null:
			return []
		bloc_courant = bloc_suivant
	var rids_chaine: Array[RID] = []
	for valeur in chaine:
		var bloc := valeur as BlocPoussableGrille
		if bloc == null:
			return []
		for rid in bloc._obtenir_rids_propres():
			if not rids_chaine.has(rid):
				rids_chaine.append(rid)
	for valeur in chaine:
		var bloc := valeur as BlocPoussableGrille
		if bloc == null:
			return []
		var destination: Vector2i = bloc.cellule + direction
		if not bloc.accepte_destination_poussee(destination):
			return []
		if not bloc._destination_physiquement_accessible_chaine(joueur, destination, rids_chaine):
			return []
	var dernier_bloc := chaine.back() as BlocPoussableGrille
	if dernier_bloc == null:
		return []
	var destination_finale: Vector2i = dernier_bloc.cellule + direction
	var occupant_final: Node = gestionnaire_parcours.obtenir_occupant(destination_finale)
	if occupant_final != null and not chaine.has(occupant_final):
		return []
	if gestionnaire_parcours.cellule_est_reservee(destination_finale, self):
		return []
	return chaine

func _destination_physiquement_accessible_chaine(joueur: CharacterBody2D, destination: Vector2i, rids_chaine: Array[RID]) -> bool:
	if deplacement_grille == null or collision_shape == null or collision_shape.shape == null:
		return true
	var delta_monde: Vector2 = deplacement_grille.cellule_vers_monde(destination) - deplacement_grille.cellule_vers_monde(cellule)
	var parametres := PhysicsShapeQueryParameters2D.new()
	parametres.shape = collision_shape.shape
	parametres.transform = collision_shape.global_transform
	parametres.collision_mask = masque_obstacles
	parametres.collide_with_bodies = true
	parametres.collide_with_areas = false
	var exclusions: Array[RID] = []
	for rid in rids_chaine:
		if not exclusions.has(rid):
			exclusions.append(rid)
	if joueur != null and is_instance_valid(joueur) and not exclusions.has(joueur.get_rid()):
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

func _obtenir_rids_propres() -> Array[RID]:
	var resultat: Array[RID] = []
	if corps_collision != null and is_instance_valid(corps_collision):
		resultat.append(corps_collision.get_rid())
	return resultat

func _terminer_poussee_chaine() -> void:
	if not _chaine_en_deplacement:
		return
	var chaine_terminee: Array[Node] = _chaine_validee.duplicate()
	var direction: Vector2i = _direction_chaine
	var reussi: bool = gestionnaire_parcours != null and gestionnaire_parcours.terminer_poussee_chaine(self, chaine_terminee, direction)
	for index in range(chaine_terminee.size()):
		var bloc := chaine_terminee[index] as BlocPoussableGrille
		if bloc == null or not is_instance_valid(bloc):
			continue
		if reussi:
			bloc.global_position = _positions_destination_chaine[index]
			bloc.cellule += direction
		else:
			bloc.global_position = _positions_depart_chaine[index]
		bloc._en_deplacement_occupant = false
		bloc.set_process(false)
	if not reussi and gestionnaire_parcours != null:
		gestionnaire_parcours.liberer_reservations_occupant(self)
	_nettoyer_chaine(false)
	if not reussi:
		return
	for valeur in chaine_terminee:
		var bloc := valeur as BlocPoussableGrille
		if bloc != null and is_instance_valid(bloc):
			bloc._apres_poussee_chaine()

func _apres_poussee_chaine() -> void:
	if comportement_vide != ComportementVide.TOMBE or gestionnaire_parcours == null:
		return
	if not gestionnaire_parcours.cellule_est_sure(cellule):
		_tomber()

func quand_sol_disparait(cellule_sans_sol: Vector2i) -> void:
	if cellule_sans_sol != cellule or _en_deplacement_occupant:
		return
	if comportement_vide == ComportementVide.TOMBE:
		_tomber()

func _tomber() -> void:
	if gestionnaire_parcours != null and is_instance_valid(gestionnaire_parcours):
		gestionnaire_parcours.retirer_occupant(self, cellule)
	visible = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	queue_free()

func _nettoyer_chaine(liberer_reservations: bool = true) -> void:
	if liberer_reservations and gestionnaire_parcours != null:
		gestionnaire_parcours.liberer_reservations_occupant(self)
	_chaine_en_deplacement = false
	_direction_chaine = Vector2i.ZERO
	_chaine_validee.clear()
	_positions_depart_chaine.clear()
	_positions_destination_chaine.clear()
	_duree_chaine_s = 0.0
	_temps_chaine_s = 0.0

func _exit_tree() -> void:
	if _chaine_en_deplacement and gestionnaire_parcours != null and is_instance_valid(gestionnaire_parcours):
		gestionnaire_parcours.liberer_reservations_occupant(self)
	super()
