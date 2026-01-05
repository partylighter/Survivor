extends Node
class_name Sante

signal damaged(amount: int, source: Node)
signal died

@export var max_pv: int = 100

var pv: float
var overheal_pv: float = 0.0


func _ready() -> void:
	pv = max_pv
	overheal_pv = 0.0


func apply_damage(amount: int, source: Node) -> void:
	var a = max(amount, 0)
	if a <= 0:
		return

	if overheal_pv > 0.0:
		var use_over = min(overheal_pv, float(a))
		overheal_pv -= use_over
		a -= int(use_over)

	if a > 0:
		pv = max(pv - a, 0)
		emit_signal("damaged", a, source)
		if pv <= 0.0:
			pv = 0.0
			emit_signal("died")



func heal(amount: int) -> void:
	var heal_value = max(amount, 0)
	if heal_value <= 0.0:
		return

	var manque := float(max_pv) - pv
	if manque > 0.0:
		var use_for_pv = min(heal_value, manque)
		pv += use_for_pv
		heal_value -= use_for_pv

	if heal_value > 0.0:
		overheal_pv += heal_value


func add_overheal(amount: float) -> void:
	var v = max(amount, 0.0)
	if v > 0.0:
		overheal_pv += v


func set_full_pv() -> void:
	pv = max_pv


func is_dead() -> bool:
	return pv <= 0.0


func get_overheal() -> float:
	return overheal_pv
