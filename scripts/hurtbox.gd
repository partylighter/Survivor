extends Area2D
class_name HurtBox

@export_node_path("Node") var chemin_sante: NodePath
var sante: Sante

func _ready() -> void:
	sante = get_node(chemin_sante) as Sante

func tek_it(damage: int, source: Node) -> void:
	if sante:
		sante.apply_damage(damage, source)
