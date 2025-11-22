extends CharacterBody2D
class_name Player

@export var speed: float = 500.0

func _ready() -> void:
	add_to_group("joueur_principal")

func _physics_process(_dt: float) -> void:
	var dir := Input.get_vector("gauche","droite","haut","bas")
	velocity = dir.normalized() * speed
	move_and_slide()
