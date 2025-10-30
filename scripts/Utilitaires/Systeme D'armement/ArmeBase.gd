# ArmeBase.gd
extends Node2D
class_name ArmeBase

@export var nom_arme: StringName = &"arme"
@export var degats: int = 10
@export var duree_active_s: float = 0.12
@export var cooldown_s: float = 0.3
@export var recul_force: float = 200.0
@export var ref_scene_equipee: PackedScene
@export var scene_source: PackedScene
@export var debug_enabled: bool = true

var porteur: Node2D = null
var _pret: bool = true

func _d(m:String)->void:
	if debug_enabled: print("[ArmeBase]", Time.get_ticks_msec(), m)

func equipe_par(p: Node2D) -> void:
	porteur = p
	_d("EQUIPE_PAR porteur=" + (p.name if p else "null"))

func peut_attaquer() -> bool:
	_d("PEUT_ATTAQUER pret=" + str(_pret))
	return _pret

func attaquer() -> void:
	_d("ATTAQUER non_implemente nom=" + str(nom_arme))
