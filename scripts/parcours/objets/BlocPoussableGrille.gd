extends OccupantGrille
class_name BlocPoussableGrille

enum ComportementVide {
	INTERDIT,
	TOMBE
}

@export_group("Poussée")
@export var comportement_vide: ComportementVide = ComportementVide.TOMBE

func peut_etre_pousse_par_joueur(joueur: CharacterBody2D, direction: Vector2i) -> bool:
	if _en_deplacement_occupant or gestionnaire_parcours == null:
		return false
	if abs(direction.x) + abs(direction.y) != 1:
		return false
	if not gestionnaire_parcours.cellule_est_sure(cellule):
		return false
	var destination: Vector2i = cellule + direction
	if not gestionnaire_parcours.cellule_disponible_pour_occupant(destination, self):
		return false
	if comportement_vide == ComportementVide.INTERDIT and not gestionnaire_parcours.cellule_est_sure(destination):
		return false
	return destination_physiquement_accessible(joueur, destination)

func demarrer_poussee_joueur(joueur: CharacterBody2D, direction: Vector2i, duree_s: float) -> bool:
	if not peut_etre_pousse_par_joueur(joueur, direction):
		return false
	return _demarrer_deplacement_occupant(cellule + direction, duree_s, true)

func _doit_occuper_destination(destination: Vector2i) -> bool:
	return gestionnaire_parcours != null and gestionnaire_parcours.cellule_est_sure(destination)

func _apres_deplacement_occupant(_ancienne_cellule: Vector2i, _destination: Vector2i, reussi: bool, destination_occupee: bool) -> void:
	if not reussi or destination_occupee:
		return
	_tomber()

func quand_sol_disparait(cellule_sans_sol: Vector2i) -> void:
	if cellule_sans_sol != cellule or _en_deplacement_occupant:
		return
	if gestionnaire_parcours != null and is_instance_valid(gestionnaire_parcours):
		gestionnaire_parcours.retirer_occupant(self, cellule)
	_tomber()

func _tomber() -> void:
	visible = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	queue_free()
