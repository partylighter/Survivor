extends Node2D
class_name ArmeBase

@export var nom_arme: StringName = &"arme"
@export var degats: int = 10
@export var duree_active_s: float = 0.12
@export var cooldown_s: float = 0.3
@export var recul_force: float = 200.0
@export var ref_scene_equipee: PackedScene

var porteur: Node2D = null
var _pret: bool = true

func equipe_par(p: Node2D) -> void:
	porteur = p

func peut_attaquer() -> bool:
	return _pret

func attaquer() -> void:
	pass
