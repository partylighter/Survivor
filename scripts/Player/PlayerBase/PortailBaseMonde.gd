extends Area2D
class_name PortailBaseMonde

@export var chemin_spawn_monde: NodePath
@export var chemin_spawn_base: NodePath

var spawn_monde: Node2D
var spawn_base: Node2D

func _ready() -> void:
	print("[Portail] _ready")
	spawn_monde = get_node_or_null(chemin_spawn_monde) as Node2D
	spawn_base = get_node_or_null(chemin_spawn_base) as Node2D
	print("[Portail] spawn_monde =", spawn_monde, " spawn_base =", spawn_base)

func _on_body_entered(body: Node) -> void:
	print("[Portail] body_entered :", body, " name=", body.name)

	if not (body is Player):
		print("[Portail] body n'est PAS un Player")
		return

	var joueur := body as Player
	print("[Portail] body EST un Player, zone_actuelle =", EtatJeu.zone_actuelle)

	if EtatJeu.zone_actuelle == EtatJeu.Zone.MONDE:
		print("[Portail] -> MONDE vers BASE")
		EtatJeu.derniere_position_monde = joueur.global_position
		EtatJeu.zone_actuelle = EtatJeu.Zone.BASE
		if spawn_base:
			print("[Portail] TP vers base :", spawn_base.global_position)
			joueur.global_position = spawn_base.global_position
		else:
			print("[Portail] ERREUR : spawn_base manquant")
	else:
		print("[Portail] -> BASE vers MONDE")
		EtatJeu.zone_actuelle = EtatJeu.Zone.MONDE
		if EtatJeu.derniere_position_monde != Vector2.ZERO:
			print("[Portail] TP vers derniere_position_monde :", EtatJeu.derniere_position_monde)
			joueur.global_position = EtatJeu.derniere_position_monde
		elif spawn_monde:
			print("[Portail] TP vers spawn_monde :", spawn_monde.global_position)
			joueur.global_position = spawn_monde.global_position
		else:
			print("[Portail] ERREUR : aucun spawn monde")
