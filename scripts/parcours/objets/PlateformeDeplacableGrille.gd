extends OccupantGrille
class_name PlateformeDeplacableGrille

func initialiser_parcours(gestionnaire) -> void:
	super(gestionnaire)
	if _enregistre and gestionnaire_parcours != null:
		gestionnaire_parcours.enregistrer_sol_dynamique(self, cellule)

func autorise_joueur_sur_cellule() -> bool:
	return not _en_deplacement_occupant

func est_deplacable_manuellement_par_joueur() -> bool:
	return true

func peut_deplacer_manuellement_par_joueur(joueur: CharacterBody2D, direction: Vector2i) -> bool:
	if _en_deplacement_occupant or gestionnaire_parcours == null or deplacement_grille == null:
		return false
	if abs(direction.x) + abs(direction.y) != 1:
		return false
	var cellule_joueur: Vector2i = deplacement_grille.obtenir_cellule_actuelle()
	if cellule_joueur == cellule or cellule_joueur + direction != cellule:
		return false
	var destination: Vector2i = cellule + direction
	if not gestionnaire_parcours.cellule_disponible_pour_occupant(destination, self):
		return false
	return destination_physiquement_accessible(joueur, destination)

func demarrer_deplacement_manuel_par_joueur(joueur: CharacterBody2D, direction: Vector2i) -> bool:
	if not peut_deplacer_manuellement_par_joueur(joueur, direction):
		return false
	return _demarrer_deplacement_occupant(cellule + direction, duree_deplacement_s, false)

func _avant_deplacement_occupant(destination: Vector2i) -> void:
	if gestionnaire_parcours != null:
		gestionnaire_parcours.enregistrer_sol_dynamique(self, destination)

func _apres_deplacement_occupant(ancienne_cellule: Vector2i, destination: Vector2i, reussi: bool, _destination_occupee: bool) -> void:
	if gestionnaire_parcours == null:
		return
	if reussi:
		call_deferred("_retirer_ancien_sol", ancienne_cellule)
	else:
		gestionnaire_parcours.retirer_sol_dynamique(self, destination)

func _retirer_ancien_sol(ancienne_cellule: Vector2i) -> void:
	if gestionnaire_parcours != null and is_instance_valid(gestionnaire_parcours) and ancienne_cellule != cellule:
		gestionnaire_parcours.retirer_sol_dynamique(self, ancienne_cellule)

func _exit_tree() -> void:
	if gestionnaire_parcours != null and is_instance_valid(gestionnaire_parcours):
		gestionnaire_parcours.retirer_sol_dynamique(self, cellule)
		if _en_deplacement_occupant and _cellule_destination != cellule:
			gestionnaire_parcours.retirer_sol_dynamique(self, _cellule_destination)
	super()
