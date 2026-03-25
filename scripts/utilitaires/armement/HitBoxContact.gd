extends Area2D
class_name HitBoxContact

@onready var shape: CollisionShape2D = $CollisionShape2D

var degats: int = 0
var recul_force: float = 0.0
var source: Node2D = null
var single_hit: bool = true

var _en_cours: bool = false
var _touchees: Dictionary = {}

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	set_deferred("monitoring", false)
	if shape:
		shape.set_deferred("disabled", true)

func configurer(dmg: int, recul: float, origine: Node2D) -> void:
	degats = dmg
	recul_force = recul
	source = origine

func activer_pendant(duree: float) -> void:
	if _en_cours:
		return
	_en_cours = true
	_touchees.clear()
	set_deferred("monitoring", true)
	if shape:
		shape.set_deferred("disabled", false)
	await get_tree().create_timer(duree).timeout
	set_deferred("monitoring", false)
	if shape:
		shape.set_deferred("disabled", true)
	_en_cours = false

func _on_area_entered(a: Area2D) -> void:
	if a is HurtBox:
		if single_hit and _touchees.has(a):
			return

		(a as HurtBox).tek_it(degats, source if source else self)

		var cible: Node = a.get_parent()
		if cible and cible.has_method("appliquer_recul_depuis"):
			var origine: Node2D = source if source is Node2D else self
			cible.appliquer_recul_depuis(origine, recul_force)

		if single_hit:
			_touchees[a] = true
