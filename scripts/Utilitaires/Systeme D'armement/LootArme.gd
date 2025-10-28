extends Node2D
class_name LootArme

@export var arme_scene: PackedScene
@export var ralentissement: float = 8.0

@onready var sprite: Sprite2D = $Sprite2D

var linear_velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var _temps: float = 0.0

func definir_texture(tex: Texture2D) -> void:
	if sprite:
		sprite.texture = tex

func _physics_process(dt: float) -> void:
	position += linear_velocity * dt
	rotation += angular_velocity * dt
	linear_velocity = linear_velocity.move_toward(Vector2.ZERO, ralentissement * dt)
	angular_velocity = move_toward(angular_velocity, 0.0, ralentissement * dt)
