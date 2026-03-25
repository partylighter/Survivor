extends Node

enum Zone {
	MONDE,
	BASE
}

var zone_actuelle: int = Zone.MONDE

var derniere_position_monde: Vector2 = Vector2.ZERO
var position_monde_valide: bool = false

var sortie_monde_local: Vector2 = Vector2.ZERO
var sortie_monde_local_valide: bool = false

var transition_en_cours: bool = false

func entrer_base(joueur: Player, spawn_base: Node2D, spawn_monde: Node2D) -> void:
	if joueur == null:
		return

	zone_actuelle = Zone.BASE
	joueur.set_dash_autorise(false)
	joueur.velocity = Vector2.ZERO

	derniere_position_monde = joueur.global_position
	position_monde_valide = true

	if spawn_monde != null:
		sortie_monde_local = spawn_monde.to_local(joueur.global_position)
		sortie_monde_local_valide = true
	else:
		sortie_monde_local = Vector2.ZERO
		sortie_monde_local_valide = false

	if spawn_base != null:
		joueur.global_position = spawn_base.global_position
	else:
		print("[EtatJeu] ERREUR : spawn_base manquant")

func sortir_base(joueur: Player, spawn_monde: Node2D) -> void:
	if joueur == null:
		return

	zone_actuelle = Zone.MONDE
	joueur.set_dash_autorise(true)
	joueur.velocity = Vector2.ZERO

	if spawn_monde != null:
		var local := sortie_monde_local if sortie_monde_local_valide else Vector2.ZERO
		joueur.global_position = spawn_monde.to_global(local)
	elif position_monde_valide:
		joueur.global_position = derniere_position_monde
	else:
		print("[EtatJeu] ERREUR : aucun spawn monde et aucune position sauvegardée")
