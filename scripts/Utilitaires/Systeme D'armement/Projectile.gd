extends Area2D
class_name Projectile

@onready var shape: CollisionShape2D = $CollisionShape2D

@export var duree_vie_s: float = 1.5
@export var vitesse_px_s: float = 1400.0

var _degats: int = 0
var _dir: Vector2 = Vector2.ZERO
var _recul_force: float = 0.0
var _source: Node2D = null

var _detruit: bool = false
var _temps: float = 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)

# Accepte: (dmg, dir, recul, src)   OU   (dmg, dir, vitesse, recul, src)
func configurer(dmg: int, direction: Vector2, a, b = null, c = null) -> void:
	_degats = dmg
	_dir = direction.normalized()
	if c != null:
		# Ancien appel (5 args) : a=vitesse, b=recul, c=src
		# On peut ignorer 'a' pour garder la vitesse locale, ou l'utiliser pour override:
		# vitesse_px_s = float(a)   # <- décommente si tu veux autoriser l'override
		_recul_force = float(b)
		_source = c as Node2D
	else:
		# Nouvel appel (4 args) : a=recul, b=src
		_recul_force = float(a)
		_source = b as Node2D

func _physics_process(dt: float) -> void:
	position += _dir * vitesse_px_s * dt
	_temps += dt
	if _temps >= duree_vie_s:
		queue_free()

func _on_area_entered(a: Area2D) -> void:
	if _detruit:
		return
	if a is HurtBox:
		(a as HurtBox).tek_it(_degats, _source if _source else self)
		var cible: Node = a.get_parent()
		if cible and cible.has_method("appliquer_recul_depuis"):
			var origine: Node2D = _source if _source is Node2D else self
			cible.appliquer_recul_depuis(origine, _recul_force)
		_detruit = true
		queue_free()
