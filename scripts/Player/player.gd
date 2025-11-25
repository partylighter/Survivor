extends CharacterBody2D
class_name Player

@export var speed: float = 500.0
@onready var gestionnaire_loot: GestionnaireLoot = $GestionnaireLoot

func _ready() -> void:
	add_to_group("joueur_principal")

func _physics_process(_dt: float) -> void:
	var dir := Input.get_vector("gauche","droite","haut","bas")
	velocity = dir.normalized() * speed
	move_and_slide()


func on_loot_collected(payload: Dictionary) -> void:
	if gestionnaire_loot:
		gestionnaire_loot.on_loot_collecte(payload)
