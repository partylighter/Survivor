extends Resource
class_name StatsBase

@export_group("Santé")
@export var sante_max: int = 400

@export_group("Réserve d'énergie")
@export var reserve_energie_max: float = 100.0
@export var conso_idle_par_s: float = 0.0
@export var conso_mouvement_par_s: float = 2.2
@export var conso_boost_par_s: float = 0.0
@export var recharge_par_s: float = 0.0
