extends Node2D
class_name SuiveurSelectionPlaceholder

@export_node_path("Node2D") var chemin_cible: NodePath
@export var decalage: Vector2 = Vector2.ZERO
@export_range(0.1, 20.0, 0.1) var vitesse_suivi: float = 4.0

@onready var cible: Node2D = get_node_or_null(chemin_cible) as Node2D

func _process(delta: float) -> void:
	if cible == null:
		return
	var position_voulue: Vector2 = cible.global_position + decalage
	global_position = global_position.lerp(position_voulue, 1.0 - exp(-vitesse_suivi * delta))
