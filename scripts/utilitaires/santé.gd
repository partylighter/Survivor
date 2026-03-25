extends Node
class_name Sante

signal damaged(amount: int, source: Node)
signal died

@export var max_pv: int = 100

var pv: float = 0.0
var overheal_pv: float = 0.0

func _ready() -> void:
	pv = float(max_pv)
	overheal_pv = 0.0

func apply_damage(amount: int, source: Node) -> void:
	var a: int = max(amount, 0)
	if a <= 0:
		return

	if overheal_pv > 0.0:
		var use_over: float = minf(overheal_pv, float(a))
		overheal_pv -= use_over
		a -= roundi(use_over)

	if a > 0:
		pv = maxf(pv - float(a), 0.0)
		emit_signal("damaged", a, source)
		if pv <= 0.0:
			pv = 0.0
			emit_signal("died")

func heal(amount: int) -> void:
	var heal_value: float = maxf(float(amount), 0.0)
	if heal_value <= 0.0:
		return

	var manque: float = float(max_pv) - pv
	if manque > 0.0:
		var use_for_pv: float = minf(heal_value, manque)
		pv += use_for_pv
		heal_value -= use_for_pv

	if heal_value > 0.0:
		overheal_pv += heal_value

func add_overheal(amount: float) -> void:
	var v: float = maxf(amount, 0.0)
	if v > 0.0:
		overheal_pv += v

func set_full_pv() -> void:
	pv = float(max_pv)
	overheal_pv = 0.0

func is_dead() -> bool:
	return pv <= 0.0

func get_overheal() -> float:
	return overheal_pv
