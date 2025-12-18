extends Area2D
class_name PortailBaseMonde

@export var chemin_spawn_monde: NodePath
@export var chemin_spawn_base: NodePath

var spawn_monde: Node2D
var spawn_base: Node2D

func _ready() -> void:
	spawn_monde = get_node_or_null(chemin_spawn_monde) as Node2D
	spawn_base = get_node_or_null(chemin_spawn_base) as Node2D

func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return

	var joueur := body as Player

	if EtatJeu.zone_actuelle == EtatJeu.Zone.MONDE:
		EtatJeu.derniere_position_monde = joueur.global_position
		EtatJeu.zone_actuelle = EtatJeu.Zone.BASE
		joueur.set_dash_autorise(false)
		joueur.velocity = Vector2.ZERO
		if spawn_base:
			joueur.global_position = spawn_base.global_position
		else:
			print("[Portail] ERREUR : spawn_base manquant")
	else:
		EtatJeu.zone_actuelle = EtatJeu.Zone.MONDE
		joueur.set_dash_autorise(true)
		joueur.velocity = Vector2.ZERO
		if EtatJeu.derniere_position_monde != Vector2.ZERO:
			joueur.global_position = EtatJeu.derniere_position_monde
		elif spawn_monde:
			print("[Portail] TP vers spawn_monde :", spawn_monde.global_position)
			joueur.global_position = spawn_monde.global_position
		else:
			print("[Portail] ERREUR : aucun spawn monde")
