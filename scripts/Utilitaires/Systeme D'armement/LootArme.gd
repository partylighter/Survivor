# LootArme.gd
extends Area2D
class_name LootArme

@export var arme_scene: PackedScene
@export var ralentissement: float = 8.0
@export var debug_enabled: bool = true

@onready var sprite: Sprite2D = $Sprite2D

var linear_velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var _temps: float = 0.0
var _en_mouvement: bool = false

func _d(m:String)->void:
	if debug_enabled: print("[LootArme]", Time.get_ticks_msec(), m)

func _ready() -> void:
	_d("READY name=" + name + " pos=" + str(global_position))

func definir_texture(tex: Texture2D) -> void:
	if sprite:
		sprite.texture = tex
		_d("SET_TEXTURE " + str(tex))

func _physics_process(dt: float) -> void:
	var v0: Vector2 = linear_velocity
	var w0: float = angular_velocity
	position += linear_velocity * dt
	rotation += angular_velocity * dt
	linear_velocity = linear_velocity.move_toward(Vector2.ZERO, ralentissement * dt)
	angular_velocity = move_toward(angular_velocity, 0.0, ralentissement * dt)
	var speed: float = linear_velocity.length()
	if not _en_mouvement and speed > 0.1:
		_en_mouvement = true
		_d("MOVE_START v=" + str(v0) + " w=" + str(w0))
	if _en_mouvement and speed <= 0.1 and abs(angular_velocity) <= 0.01:
		_en_mouvement = false
		_d("MOVE_STOP pos=" + str(global_position) + " rot=" + str(rotation))
