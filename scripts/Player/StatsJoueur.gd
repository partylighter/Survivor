extends Node
class_name StatsJoueur

@export var pv_max_base: int = 100
@export var vitesse_base: float = 500.0
@export var chance_base: float = 0.0
@export var regen_pv_base: float = 0.0
@export var dash_max_base: int = 1
@export var dash_cooldown_base: float = 1.0

var pv_max_bonus_add: int = 0
var pv_max_bonus_mult: float = 1.0

var vitesse_bonus_add: float = 0.0
var vitesse_bonus_mult: float = 1.0

var chance_bonus: float = 0.0

var regen_pv_bonus_add: float = 0.0
var regen_pv_bonus_mult: float = 1.0

var dash_max_bonus_add: int = 0
var dash_max_bonus_mult: float = 1.0

var dash_cooldown_bonus_add: float = 0.0
var dash_cooldown_bonus_mult: float = 1.0

var sante: Sante = null


func _ready() -> void:
	_sync_pv_max()


func set_sante_ref(s: Sante) -> void:
	sante = s
	_sync_pv_max()


func get_pv_max_effectif() -> int:
	return int(round((pv_max_base + pv_max_bonus_add) * pv_max_bonus_mult))


func get_vitesse_effective() -> float:
	return (vitesse_base + vitesse_bonus_add) * vitesse_bonus_mult


func get_chance() -> float:
	return chance_base + chance_bonus


func get_regen_pv_effective() -> float:
	return (regen_pv_base + regen_pv_bonus_add) * regen_pv_bonus_mult


func get_dash_max_effectif() -> int:
	return int(round((dash_max_base + dash_max_bonus_add) * dash_max_bonus_mult))


func get_dash_cooldown_effectif() -> float:
	return (dash_cooldown_base + dash_cooldown_bonus_add) * dash_cooldown_bonus_mult


func ajouter_vitesse_add(v: float) -> void:
	vitesse_bonus_add += v


func ajouter_vitesse_mult(m: float) -> void:
	vitesse_bonus_mult *= m


func ajouter_pv_max_add(v: int) -> void:
	pv_max_bonus_add += v
	_sync_pv_max()


func ajouter_pv_max_mult(m: float) -> void:
	pv_max_bonus_mult *= m
	_sync_pv_max()


func ajouter_chance(v: float) -> void:
	chance_bonus += v


func ajouter_regen_pv_add(v: float) -> void:
	regen_pv_bonus_add += v


func ajouter_regen_pv_mult(m: float) -> void:
	regen_pv_bonus_mult *= m


func ajouter_dash_max_add(v: int) -> void:
	dash_max_bonus_add += v


func ajouter_dash_max_mult(m: float) -> void:
	dash_max_bonus_mult *= m


func ajouter_dash_cooldown_add(v: float) -> void:
	dash_cooldown_bonus_add += v


func ajouter_dash_cooldown_mult(m: float) -> void:
	dash_cooldown_bonus_mult *= m


func _sync_pv_max() -> void:
	if sante == null or not is_instance_valid(sante):
		return
	var max_eff: int = get_pv_max_effectif()
	sante.max_pv = max_eff
	if sante.pv > max_eff:
		sante.pv = max_eff
