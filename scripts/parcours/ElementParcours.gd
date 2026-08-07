extends Node2D
class_name ElementParcours

@export var recaler_sur_grille: bool = true

var cellule: Vector2i = Vector2i.ZERO
var _initialise: bool = false

func initialiser(deplacement_grille: GestionDeplacementGrilleJoueur) -> void:
	if deplacement_grille == null:
		return
	cellule = deplacement_grille.monde_vers_cellule(global_position)
	if recaler_sur_grille:
		global_position = deplacement_grille.cellule_vers_monde(cellule)
	_initialise = true

func est_initialise() -> bool:
	return _initialise

func activer(_joueur: CharacterBody2D, _gestionnaire) -> void:
	pass
