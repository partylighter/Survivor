extends Node
class_name Sante

signal damaged(amount: int, source: Node)
signal died

@export var max_pv: int = 100
var pv: int

func _ready() -> void:
	pv = max_pv

func apply_damage(amount: int, source: Node) -> void:
	var a: int = max(amount, 0)
	pv = clamp(pv - a, 0, max_pv)
	emit_signal("damaged", a, source)
	if pv == 0:
		emit_signal("died")

func heal(amount: int) -> void:
	pv = clamp(pv + max(amount, 0), 0, max_pv)

func is_dead() -> bool:
	return pv == 0
