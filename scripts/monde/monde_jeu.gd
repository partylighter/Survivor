extends Node2D
@export var centrer_souris_au_lancement: bool = true
@export var chemin_joueur: NodePath = NodePath("Archere")
func _ready() -> void:
	if centrer_souris_au_lancement:
		call_deferred("_centrer_souris")
func _centrer_souris() -> void:
	var joueur := get_node_or_null(chemin_joueur) as Node2D
	if joueur == null:
		Input.warp_mouse(get_viewport().get_visible_rect().size * 0.5)
		return
	var position_ecran := get_viewport().get_canvas_transform() * joueur.global_position
	Input.warp_mouse(position_ecran)
