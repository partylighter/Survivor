extends Area2D
class_name Projectile

@onready var shape: CollisionShape2D = $CollisionShape2D

@export var duree_vie_s: float = 1.5

var _degats: int = 0
var _dir: Vector2 = Vector2.ZERO
var _vitesse: float = 0.0
var _recul_force: float = 0.0
var _source: Node2D = null

var _detruit: bool = false
var _temps: float = 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func configurer(dmg: int, direction: Vector2, vitesse: float, recul: float, origine: Node2D) -> void:
	_degats = dmg
	_dir = direction
	_vitesse = vitesse
	_recul_force = recul
	_source = origine

func _physics_process(dt: float) -> void:
	# avance tout droit
	position += _dir * _vitesse * dt

	# timer de durée de vie (balle disparaît après un certain temps pour éviter qu'elle traverse toute la map)
	_temps += dt
	if _temps >= duree_vie_s:
		queue_free()

func _on_area_entered(a: Area2D) -> void:
	if _detruit:
		return

	if a is HurtBox:
		# applique dégâts
		(a as HurtBox).tek_it(_degats, _source if _source else self)

		# applique recul si la cible le gère
		var cible: Node = a.get_parent()
		if cible and cible.has_method("appliquer_recul_depuis"):
			var origine: Node2D = _source if _source is Node2D else self
			cible.appliquer_recul_depuis(origine, _recul_force)

		_detruit = true
		queue_free()
