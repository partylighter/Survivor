extends Node2D
class_name EspritAspirant

@export var decalage: Vector2 = Vector2.ZERO
@export var vitesse_suivi: float = 5.0

var proprietaire: Node2D

func _process(delta: float) -> void:
	if not is_instance_valid(proprietaire):
		return
	var position_voulue: Vector2 = proprietaire.global_position + decalage
	global_position = global_position.lerp(position_voulue, 1.0 - exp(-vitesse_suivi * delta))

func definir_proprietaire(nouveau_proprietaire: Node2D) -> void:
	proprietaire = nouveau_proprietaire

func definir_decalage(nouveau_decalage: Vector2) -> void:
	decalage = nouveau_decalage
