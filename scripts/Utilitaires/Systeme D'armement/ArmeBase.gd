extends Node2D
class_name ArmeBase

@export var nom_arme: StringName = &"arme"
@export var degats: int = 10
@export var duree_active_s: float = 0.12
@export var cooldown_s: float = 0.3
@export var recul_force: float = 200.0
@export var ref_scene_equipee: PackedScene
@export var scene_source: PackedScene
@export var debug_enabled: bool = false
@export_node_path("Area2D") var chemin_pickup: NodePath
var _pickup: Area2D
var est_au_sol: bool = true
var porteur: Node2D = null
var _pret: bool = true



func _ready() -> void:
	if chemin_pickup != NodePath():
		_pickup = get_node(chemin_pickup) as Area2D
	_maj_etat_pickup()

func _maj_etat_pickup() -> void:
	if _pickup:
		_pickup.monitoring = est_au_sol
		_pickup.monitorable = est_au_sol

func _d(m:String)->void:
	if debug_enabled: print("[ArmeBase]", Time.get_ticks_msec(), m)

func equipe_par(p: Node2D) -> void:
	porteur = p
	est_au_sol = false
	_maj_etat_pickup()
	@warning_ignore("incompatible_ternary")
	_d("EQUIPE_PAR porteur=" + (p.name if p else "null"))

func liberer_au_sol() -> void:
	porteur = null
	est_au_sol = true
	_maj_etat_pickup()

func peut_attaquer() -> bool:
	_d("PEUT_ATTAQUER pret=" + str(_pret))
	return _pret

func attaquer() -> void:
	_d("ATTAQUER non_implemente nom=" + str(nom_arme))
