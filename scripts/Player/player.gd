extends CharacterBody2D
class_name Player

@export var speed: float = 500.0
@export_node_path("HitBox") var chemin_hitbox: NodePath
@export var duree_attaque_s: float = 0.12

@onready var hitbox: HitBox = get_node(chemin_hitbox) as HitBox

func _physics_process(_dt: float) -> void:
	var dir := Input.get_vector("gauche","droite","haut","bas")
	velocity = dir.normalized() * speed
	move_and_slide()
	if Input.is_action_just_pressed("attaque") and hitbox:
		hitbox.activer_pendant(duree_attaque_s)
