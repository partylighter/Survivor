extends Node2D
class_name ElementParcours

@export var ancre_cellule: Node2D

var cellule: Vector2i = Vector2i.ZERO
var _initialise: bool = false

func initialiser(deplacement_grille: GestionDeplacementGrilleJoueur) -> void:
	if deplacement_grille == null:
		return
	var position_logique: Vector2 = global_position
	if ancre_cellule != null:
		position_logique = ancre_cellule.global_position
	cellule = deplacement_grille.monde_vers_cellule(position_logique)
	_initialise = true

func est_initialise() -> bool:
	return _initialise

func activer(_joueur: CharacterBody2D, _gestionnaire) -> void:
	pass
